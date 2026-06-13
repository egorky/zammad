# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  class TemplateDeliver < Service::Ticket::Article::Type::BaseDeliver
    private

    def channel_adapter
      'whatsapp'.freeze
    end

    def check_channel!
      super

      error!(message: "Recipient phone number is missing in ticket.preferences['whatsapp']['from']['phone_number'] for Ticket.find(#{ticket.id})") if !from_phone_number
      error!(message: __('WhatsApp template data is missing in article preferences.')) if template_preferences.blank?
      error!(message: __('WhatsApp template name is missing.')) if template_name.blank?
      error!(message: __('WhatsApp template language is missing.')) if template_language.blank?
    end

    def deliver_arguments
      {
        recipient_number:  from_phone_number,
        message_type:      'template',
        template_name:     template_name,
        template_language: template_language,
        components_json:   components_json,
      }
    end

    def handle_deliver_result
      article.preferences['whatsapp'] = {
        message_id: result[:id],
      }
      article.message_id = result[:id]
    end

    def from_phone_number
      @from_phone_number ||= ticket.preferences.dig('whatsapp', 'from', 'phone_number')
    end

    def template_preferences
      @template_preferences ||= article.preferences['whatsapp_template']
    end

    def template_name
      template_preferences&.dig('name')
    end

    def template_language
      template_preferences&.dig('language')
    end

    def components_json
      template_preferences&.dig('components_json') || []
    end
  end
end
