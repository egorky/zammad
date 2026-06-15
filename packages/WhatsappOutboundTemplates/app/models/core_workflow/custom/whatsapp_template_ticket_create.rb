# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CoreWorkflow::Custom::WhatsappTemplateTicketCreate < CoreWorkflow::Custom::Backend
  WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'.freeze
  TEMPLATE_FIELDS = %w[title body attachments].freeze

  def saved_attribute_match?
    object?(Ticket) && ticket_create?
  end

  def selected_attribute_match?
    saved_attribute_match?
  end

  def ticket_create?
    screen?('create_middle')
  end

  def whatsapp_template_create?
    [params['articleSenderType'], params['formSenderType']].include?(WHATSAPP_TEMPLATE_CREATE_TYPE)
  end

  def perform
    if whatsapp_template_create?
      hide_template_fields
    else
      show_template_fields
    end
  end

  private

  def hide_template_fields
    TEMPLATE_FIELDS.each do |field|
      result('hide', field)
      result('set_optional', field)
    end
  end

  def show_template_fields
    TEMPLATE_FIELDS.each do |field|
      result('show', field)
    end

    result('set_mandatory', 'title')
    result('set_mandatory', 'body')
  end
end
