# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Whatsapp::Account::Templates < Whatsapp::Client

  attr_reader :business_id, :templates_api

  def initialize(access_token:, business_id:)
    super(access_token:)

    @business_id   = business_id
    @templates_api = WhatsappSdk::Api::Templates.new client
  end

  def list
    all_templates = []
    after = nil

    loop do
      params = { limit: 100 }
      params['after'] = after if after.present?

      response = templates_api.send_request(
        endpoint:  "#{business_id}/message_templates",
        http_method: 'get',
        params:    params,
      )

      Array(response['data']).each do |template_data|
        all_templates << map_template(WhatsappSdk::Resource::Template.from_hash(template_data))
      end

      after = response.dig('paging', 'cursors', 'after')
      break if after.blank?
    end

    all_templates
  rescue WhatsappSdk::Api::Responses::HttpResponseError => e
    handle_error(response: e)
  end

  private

  def map_template(template)
    {
      meta_template_id: template.id,
      name:             template.name,
      language:         template.language,
      status:           template.status,
      category:         template.category,
      components:       template.components_json,
    }
  end
end
