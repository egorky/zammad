# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module TicketCreate
    WHATSAPP_TEMPLATE_ARTICLE_TYPE = 'whatsapp template message'.freeze

    def execute
      apply_whatsapp_template_ticket_data!(ticket_data)
      super
    end

    private

    def apply_whatsapp_template_ticket_data!(data)
      article = data[:article]
      return if article.blank?
      return if article[:type] != WHATSAPP_TEMPLATE_ARTICLE_TYPE

      group = data[:group]
      raise Exceptions::UnprocessableContent, __('Group is required for WhatsApp template tickets.') if group.blank?

      channel = Channel.in_area('WhatsApp::Business').find_by(group_id: group.id, active: true)
      if channel.blank?
        raise Exceptions::UnprocessableContent, __('No active WhatsApp channel found for the selected group.')
      end

      customer = resolve_customer(data)
      phone_number = extract_phone_number(customer)
      if phone_number.blank?
        raise Exceptions::UnprocessableContent, __('Customer mobile phone number is required for WhatsApp template tickets.')
      end

      data[:preferences] ||= {}
      data[:preferences].merge!(
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

    def extract_phone_number(customer)
      return if customer.blank?

      number = customer.mobile.presence || customer.phone.presence
      return if number.blank?

      number.to_s.gsub(/\D/, '')
    end
  end
end
