# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module TicketCreate
    WHATSAPP_TEMPLATE_ARTICLE_TYPE = 'whatsapp template message'.freeze

    def execute
      apply_whatsapp_template_ticket_data!(ticket_data)

      if whatsapp_template_create?
        existing_ticket = find_open_whatsapp_ticket(ticket_data)
        return append_template_to_existing_ticket!(existing_ticket) if existing_ticket
      end

      super
    end

    private

    def whatsapp_template_create?
      article = ticket_data[:article]
      article.present? && article[:type] == WHATSAPP_TEMPLATE_ARTICLE_TYPE
    end

    def find_open_whatsapp_ticket(data)
      customer = resolve_customer(data)
      return if customer.blank?

      channel_id = data.dig(:preferences, :channel_id)
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

    def apply_whatsapp_template_ticket_data!(data)
      article = data[:article]
      return if article.blank?
      return if article[:type] != WHATSAPP_TEMPLATE_ARTICLE_TYPE

      group = data[:group]
      raise Exceptions::UnprocessableContent, __('Group is required for WhatsApp template tickets.') if group.blank?

      channel = resolve_whatsapp_channel(data, group)
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

    def resolve_whatsapp_channel(data, group)
      channel_id = data.dig(:article, :preferences, :whatsapp_template, :channel_id)
      channel_id ||= data.dig(:article, :preferences, 'whatsapp_template', 'channel_id')

      if channel_id.present?
        channel = Channel.in_area('WhatsApp::Business').find_by(id: channel_id, active: true)
        return channel if channel.present?
      end

      Channel.in_area('WhatsApp::Business').find_by(group_id: group.id, active: true)
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
