# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class EnsureWhatsappTemplateTicketCreateTypes
  STANDARD_TYPES = %w[phone-in phone-out email-out].freeze
  WHATSAPP_TYPE  = 'whatsapp-template-out'.freeze

  def self.up
    setting = Setting.find_by(name: 'ui_ticket_create_available_types')
    return if setting.blank?

    current_state = Array(setting.state)
    STANDARD_TYPES.each do |type|
      current_state << type unless current_state.include?(type)
    end
    current_state << WHATSAPP_TYPE unless current_state.include?(WHATSAPP_TYPE)

    setting.state = current_state.uniq
    setting.save!
  end

  def self.down
    # no-op: keep user-configured state
  end
end
