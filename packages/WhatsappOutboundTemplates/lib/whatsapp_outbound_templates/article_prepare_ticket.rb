# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module ArticlePrepareTicket
    extend ActiveSupport::Concern

    included do
      before_create :whatsapp_outbound_templates_prepare_ticket_preferences
    end

    private

    def whatsapp_outbound_templates_prepare_ticket_preferences
      return if Setting.get('import_mode')
      return if !sender_id
      return if !WhatsappOutboundTemplates::Preferences.whatsapp_template_article_record?(self)

      sender = Ticket::Article::Sender.lookup(id: sender_id)
      return if sender.nil?
      return if sender.name == 'Customer'

      return if ticket.preferences['channel_id'].present?

      WhatsappOutboundTemplates::Preferences.apply_to_ticket!(ticket, article: self)
    end
  end
end
