# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Rails.application.config.to_prepare do
  Ticket::Article.include WhatsappOutboundTemplates::EnqueueJob
  Service::Ticket::Create.prepend WhatsappOutboundTemplates::TicketCreate

  Channel::Driver::Whatsapp.prepend(Module.new do
    def deliver(options, attr, notification = false)
      if attr[:message_type] == 'template'
        return deliver_template(options, attr)
      end

      super
    end

    private

    def deliver_template(options, attr)
      return true if Setting.get('import_mode')

      message = Whatsapp::Outgoing::Message::Template.new(
        access_token:     options[:access_token],
        phone_number_id:  options[:phone_number_id],
        recipient_number: attr[:recipient_number]
      )

      message.deliver(
        name:             attr[:template_name],
        language:         attr[:template_language],
        components_json:  attr[:components_json] || [],
      )
    end
  end)
end
