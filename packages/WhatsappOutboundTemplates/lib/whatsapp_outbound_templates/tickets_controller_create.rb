# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module TicketsControllerCreate
    def create
      existing_ticket = find_reusable_whatsapp_ticket
      if existing_ticket
        append_whatsapp_template_to_ticket!(existing_ticket)
        return render_reloaded_ticket(existing_ticket, status: :created)
      end

      super
    end

    private

    def find_reusable_whatsapp_ticket
      return if params[:article].blank?
      return if !WhatsappOutboundTemplates::Preferences.whatsapp_template_article?(params[:article])

      customer_id = params[:customer_id]
      return if customer_id.blank?

      channel = WhatsappOutboundTemplates::Preferences.resolve_channel_from_params(
        article: params[:article],
        group_id: params[:group_id],
      )
      return if channel.blank?

      WhatsappOutboundTemplates::Preferences.find_open_whatsapp_ticket(
        customer_id: customer_id,
        channel_id:  channel.id,
      )
    end

    def append_whatsapp_template_to_ticket!(ticket)
      Transaction.execute do
        article_create(ticket, params[:article])
        WhatsappOutboundTemplates::Preferences.ensure_follow_up_state!(ticket)
      end
    end
  end
end
