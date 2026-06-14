# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module TicketCreate
    def execute
      apply_whatsapp_template_ticket_data!

      if whatsapp_template_create?
        existing_ticket = find_open_whatsapp_ticket
        return append_template_to_existing_ticket!(existing_ticket) if existing_ticket
      end

      super
    end

    private

    def whatsapp_template_create?
      WhatsappOutboundTemplates::Preferences.whatsapp_template_article?(ticket_data[:article])
    end

    def find_open_whatsapp_ticket
      customer = resolve_customer(ticket_data)
      return if customer.blank?

      channel_id = ticket_data.dig(:preferences, :channel_id) || ticket_data.dig(:preferences, 'channel_id')
      return if channel_id.blank?

      state_ids = Ticket::State.by_category_ids(:resolved)

      Ticket.where(customer_id: customer.id).where.not(state_id: state_ids).reorder(:updated_at).find do |ticket|
        ticket_channel_id = ticket.preferences[:channel_id] || ticket.preferences['channel_id']
        ticket_channel_id.to_i == channel_id.to_i
      end
    end

    def append_template_to_existing_ticket!(ticket)
      Transaction.execute do
        handle_shared_draft(ticket_data)

        article_data = ticket_data.delete(:article)
        tag_data     = ticket_data.delete(:tags)
        link_data    = ticket_data.delete(:links)

        preprocess_article_data!(ticket, article_data)

        Pundit.authorize current_user, ticket, :update?

        Service::Ticket::Article::Create
          .with_current_user(current_user)
          .execute(article_data: article_data, ticket: ticket)

        assign_tags(ticket, tag_data)
        add_links(ticket, link_data)
        ensure_follow_up_state!(ticket)

        ticket
      end
    end

    def ensure_follow_up_state!(ticket)
      follow_up_state = Ticket::State.find_by(default_follow_up: true)
      return if follow_up_state.blank?
      return if ticket.state_id == Ticket::State.find_by(default_create: true)&.id

      ticket.update!(state_id: follow_up_state.id)
    end

    def apply_whatsapp_template_ticket_data!
      article = ticket_data[:article]
      return if !WhatsappOutboundTemplates::Preferences.whatsapp_template_article?(article)

      group = ticket_data[:group]
      raise Exceptions::UnprocessableContent, __('Group is required for WhatsApp template tickets.') if group.blank?

      customer = resolve_customer(ticket_data)
      phone_number = WhatsappOutboundTemplates::Preferences.extract_phone_number(customer)
      if phone_number.blank?
        raise Exceptions::UnprocessableContent, __('Customer mobile phone number is required for WhatsApp template tickets.')
      end

      channel = WhatsappOutboundTemplates::Preferences.resolve_channel(
        ticket: Ticket.new(group: group),
        article: article,
      )
      if channel.blank?
        raise Exceptions::UnprocessableContent, __('No active WhatsApp channel found for the selected group.')
      end

      ticket_data[:preferences] ||= {}
      ticket_data[:preferences].merge!(
        channel_id:   channel.id,
        channel_area: channel.area,
        whatsapp:     {
          from: {
            phone_number: phone_number,
            display_name: customer&.fullname.presence || customer&.login,
          },
        },
      )
    end

    def resolve_customer(data)
      customer = data[:customer]
      return customer if customer.is_a?(::User)

      customer_id = data[:customer_id]
      return ::User.find_by(id: customer_id) if customer_id.present?

      nil
    end
  end
end
