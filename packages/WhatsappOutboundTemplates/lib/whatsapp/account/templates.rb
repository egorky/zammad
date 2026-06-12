# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Whatsapp::Account::Templates < Whatsapp::Client

  attr_reader :business_id, :templates_api

  def initialize(access_token:, business_id:)
    super(access_token:)

    @business_id   = business_id
    @templates_api = WhatsappSdk::Api::Templates.new client
  end

  def list
    response = templates_api.list(business_id: business_id.to_s)

    Array(response.data).map do |template|
      {
        meta_template_id: template.id,
        name:             template.name,
        language:         template.language,
        status:           template.status,
        category:         template.category,
        components:       template.components,
      }
    end
  rescue WhatsappSdk::Api::Responses::HttpResponseError => e
    handle_error(response: e)
  end
end
