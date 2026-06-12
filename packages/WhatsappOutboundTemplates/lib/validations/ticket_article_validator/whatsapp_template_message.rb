# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Validations::TicketArticleValidator
  class WhatsappTemplateMessage < Backend
    MATCHING_TYPES = ['whatsapp template message'].freeze

    def validate
      validate_ticket_state
      validate_template_data
      validate_required_variables
    end

    def validate_ticket_state
      return if Ticket::State.where(name: %w[closed merged removed]).pluck(:id).exclude?(@record.ticket.state_id)

      @record.errors.add :base, __('Reply allowed only for open tickets')
    end

    def validate_template_data
      template = @record.preferences['whatsapp_template']

      if template.blank?
        @record.errors.add :base, __('WhatsApp template is required.')
        return
      end

      if template['name'].blank?
        @record.errors.add :base, __('WhatsApp template name is required.')
      end

      if template['language'].blank?
        @record.errors.add :base, __('WhatsApp template language is required.')
      end
    end

    def validate_required_variables
      template_id = @record.preferences.dig('whatsapp_template', 'template_id')
      return if template_id.blank?

      db_template = Whatsapp::MessageTemplate.find_by(id: template_id)
      return if db_template.blank?

      variable_values = @record.preferences.dig('whatsapp_template', 'variable_values') || {}
      validate_variable_group(:body, db_template.variables['body'], variable_values['body'])
      validate_variable_group(:header, db_template.variables['header'], variable_values['header'])
    end

    def validate_variable_group(_type, definitions, values)
      Array(definitions).each_with_index do |definition, index|
        next if values&.dig(index).present?

        label = definition['label'] || definition[:label] || "Variable #{definition['position'] || definition[:position]}"
        @record.errors.add :base, format(__('%s is required.'), label)
      end
    end

    private

    def validator_applies?
      sender = Ticket::Article::Sender.lookup id: @record.sender_id

      sender.name == 'Agent'
    end
  end
end
