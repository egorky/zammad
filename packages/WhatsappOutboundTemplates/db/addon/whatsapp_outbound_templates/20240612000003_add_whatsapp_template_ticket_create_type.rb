# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddWhatsappTemplateTicketCreateType
  def self.up
    setting = Setting.find_by(name: 'ui_ticket_create_available_types')
    return if setting.blank?

    options = setting.options.deep_dup
    form_field = options.dig('form', 0)
    return if form_field.blank?

    form_field['options'] ||= {}
    form_field['options']['whatsapp-template-out'] = '4. WhatsApp template outbound'

    current_state = Array(setting.state)
    current_state << 'whatsapp-template-out' unless current_state.include?('whatsapp-template-out')

    setting.options = options
    setting.state = current_state
    setting.save!
  end

  def self.down
    setting = Setting.find_by(name: 'ui_ticket_create_available_types')
    return if setting.blank?

    options = setting.options.deep_dup
    form_field = options.dig('form', 0)
    form_field&.dig('options')&.delete('whatsapp-template-out')

    current_state = Array(setting.state)
    current_state.delete('whatsapp-template-out')

    setting.options = options
    setting.state = current_state
    setting.save!
  end
end
