# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module WhatsappOutboundTemplates
  module EnqueueJob
    extend ActiveSupport::Concern

    included do
      after_create_commit :whatsapp_outbound_templates_enqueue_job
    end

    private

    def whatsapp_outbound_templates_enqueue_job
      return true if Setting.get('import_mode')
      return true if !sender_id

      sender = Ticket::Article::Sender.lookup(id: sender_id)
      return true if sender.nil?
      return true if sender.name == 'Customer'
      return true if !whatsapp_outbound_templates_delivery_needed?

      CommunicateWhatsappTemplateJob.perform_later(id)
    end

    def whatsapp_outbound_templates_delivery_needed?
      return true if WhatsappOutboundTemplates::Preferences.whatsapp_template_preferences?(self)

      return false if !type_id

      type = Ticket::Article::Type.lookup(id: type_id)
      type&.name == 'whatsapp template message'
    end
  end
end
