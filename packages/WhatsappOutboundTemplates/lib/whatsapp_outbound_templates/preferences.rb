# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module Preferences
    WHATSAPP_TEMPLATE_ARTICLE_TYPE = 'whatsapp template message'.freeze

    module_function

    def apply_to_ticket!(ticket, article:)
      channel = resolve_channel(ticket:, article:)
      raise Exceptions::UnprocessableContent, __('No active WhatsApp channel found for the selected group.') if channel.blank?

      customer = ticket.customer
      phone_number = extract_phone_number(customer)
      if phone_number.blank?
        raise Exceptions::UnprocessableContent, __('Customer mobile phone number is required for WhatsApp template tickets.')
      end

      preferences = ticket.preferences.merge(
        'channel_id'   => channel.id,
        'channel_area' => channel.area,
        'whatsapp'     => {
          'from' => {
            'phone_number' => phone_number,
            'display_name' => customer&.fullname.presence || customer&.login,
          },
        },
      )

      ticket.update!(preferences: preferences)
    end

    def resolve_channel(ticket:, article:)
      template_prefs = template_preferences_from(article)
      channel_id = template_prefs['channel_id'] || template_prefs[:channel_id]

      if channel_id.present?
        channel = Channel.in_area('WhatsApp::Business').find_by(id: channel_id, active: true)
        return channel if channel.present?
      end

      Channel.in_area('WhatsApp::Business').find_by(group_id: ticket.group_id, active: true)
    end

    def template_preferences_from(article)
      preferences = if article.respond_to?(:preferences)
                      article.preferences
                    else
                      article[:preferences] || article['preferences'] || {}
                    end

      preferences['whatsapp_template'] || preferences[:whatsapp_template] || {}
    end

    def extract_phone_number(customer)
      return if customer.blank?

      number = customer.mobile.presence || customer.phone.presence
      return if number.blank?

      number.to_s.gsub(/\D/, '')
    end

    def whatsapp_template_article?(article_data)
      return false if article_data.blank?

      type = article_data[:type] || article_data['type']
      return type == WHATSAPP_TEMPLATE_ARTICLE_TYPE if type.present?

      type_id = article_data[:type_id] || article_data['type_id']
      return false if type_id.blank?

      Ticket::Article::Type.lookup(id: type_id)&.name == WHATSAPP_TEMPLATE_ARTICLE_TYPE
    end

    def whatsapp_template_article_record?(article)
      return false if article.type_id.blank?

      type = Ticket::Article::Type.lookup(id: article.type_id)
      type&.name == WHATSAPP_TEMPLATE_ARTICLE_TYPE
    end
  end
end
