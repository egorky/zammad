# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module ArticlePrepareTicket
    extend ActiveSupport::Concern

    included do
      before_create :whatsapp_outbound_templates_prepare_ticket
      after_create_commit :whatsapp_outbound_templates_finalize_ticket
    end

    private

    def whatsapp_outbound_templates_prepare_ticket
      return if Setting.get('import_mode')
      return if !sender_id

      sender = Ticket::Article::Sender.lookup(id: sender_id)
      return if sender.nil?
      return if sender.name == 'Customer'

      if WhatsappOutboundTemplates::Preferences.whatsapp_template_preferences?(self)
        WhatsappOutboundTemplates::Preferences.ensure_template_article_type!(self)
      end

      return if !WhatsappOutboundTemplates::Preferences.whatsapp_template_article_record?(self)

      if ticket.preferences['channel_id'].blank? || ticket.preferences.dig('whatsapp', 'from', 'phone_number').blank?
        WhatsappOutboundTemplates::Preferences.apply_to_ticket!(ticket, article: self)
      end

      whatsapp_outbound_templates_apply_metadata
    end

    def whatsapp_outbound_templates_finalize_ticket
      return if Setting.get('import_mode')
      return if !WhatsappOutboundTemplates::Preferences.whatsapp_template_article_record?(self)

      sender = Ticket::Article::Sender.lookup(id: sender_id)
      return if sender.nil?
      return if sender.name == 'Customer'

      WhatsappOutboundTemplates::Preferences.ensure_whatsapp_create_article_type!(ticket)
    end

    def whatsapp_outbound_templates_apply_metadata
      channel = Channel.lookup(id: ticket.preferences['channel_id'])
      return if channel.blank?

      phone_number = ticket.preferences.dig('whatsapp', 'from', 'phone_number')
      display_name = ticket.preferences.dig('whatsapp', 'from', 'display_name')
      return if phone_number.blank?

      self.from = whatsapp_outbound_templates_from_name(channel)
      self.to   = "#{display_name} (+#{phone_number})"
    end

    def whatsapp_outbound_templates_from_name(channel)
      if created_by_id != 1 && created_by
        return "#{created_by.firstname} #{created_by.lastname} via #{channel.options[:name]} (#{channel.options[:phone_number]})"
      end

      "#{channel.options[:name]} (#{channel.options[:phone_number]})"
    end
  end
end
