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
        'whatsapp'     => (ticket.preferences['whatsapp'] || {}).merge(
          'from' => {
            'phone_number' => phone_number,
            'display_name' => customer&.fullname.presence || customer&.login,
          },
        ),
      )

      ticket.update!(preferences: preferences)
    end

    def find_open_whatsapp_ticket(customer_id:, channel_id:)
      return if customer_id.blank? || channel_id.blank?

      state_ids = Ticket::State.by_category_ids(:resolved)

      Ticket.where(customer_id: customer_id).where.not(state_id: state_ids).reorder(:updated_at).find do |ticket|
        ticket_channel_id = ticket.preferences[:channel_id] || ticket.preferences['channel_id']
        ticket_channel_id.to_i == channel_id.to_i
      end
    end

    def resolve_channel_from_params(article:, group_id:)
      ticket = Ticket.new(group_id: group_id)
      resolve_channel(ticket: ticket, article: normalize_article_data(article))
    end

    def ensure_whatsapp_create_article_type!(ticket)
      whatsapp_message_type = Ticket::Article::Type.lookup(name: 'whatsapp message')
      return if whatsapp_message_type.blank?
      return if ticket.create_article_type_id == whatsapp_message_type.id

      ticket.update!(create_article_type_id: whatsapp_message_type.id)
    end

    def ensure_follow_up_state!(ticket)
      follow_up_state = Ticket::State.find_by(default_follow_up: true)
      return if follow_up_state.blank?
      return if ticket.state_id == Ticket::State.find_by(default_create: true)&.id

      ticket.update!(state_id: follow_up_state.id)
    end

    def normalize_article_data(article_data)
      data = article_data.respond_to?(:to_unsafe_h) ? article_data.to_unsafe_h : article_data
      data.deep_symbolize_keys
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

      data = normalize_article_data(article_data)

      template_prefs = data[:preferences]&.dig(:whatsapp_template) || data[:preferences]&.dig('whatsapp_template')
      return true if template_prefs.present? && (template_prefs[:name].present? || template_prefs['name'].present?)

      type = data[:type]
      return type == WHATSAPP_TEMPLATE_ARTICLE_TYPE if type.present?

      type_id = data[:type_id]
      return false if type_id.blank?

      Ticket::Article::Type.lookup(id: type_id)&.name == WHATSAPP_TEMPLATE_ARTICLE_TYPE
    end

    def whatsapp_template_article_record?(article)
      return true if whatsapp_template_preferences?(article)

      return false if article.type_id.blank?

      type = Ticket::Article::Type.lookup(id: article.type_id)
      type&.name == WHATSAPP_TEMPLATE_ARTICLE_TYPE
    end

    def whatsapp_template_preferences?(article)
      template_prefs = if article.respond_to?(:preferences)
                         article.preferences
                       else
                         article[:preferences] || article['preferences'] || {}
                       end

      data = template_prefs['whatsapp_template'] || template_prefs[:whatsapp_template] || {}
      data['name'].present? || data[:name].present?
    end

    def ensure_template_article_type!(article)
      whatsapp_message_type = Ticket::Article::Type.lookup(name: WHATSAPP_TEMPLATE_ARTICLE_TYPE)
      return if whatsapp_message_type.blank?
      return if article.type_id == whatsapp_message_type.id

      article.type_id = whatsapp_message_type.id
    end
  end
end
