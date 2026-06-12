# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Service::Whatsapp::MessageTemplate::Sync < Service::Base
  attr_reader :channel

  def initialize(channel_id:)
    @channel = Channel.in_area('WhatsApp::Business').find(channel_id)
  end

  def execute
    templates = fetch_remote_templates

    Transaction.execute do
      templates.each do |template_data|
        upsert_template(template_data)
      end
    end

    Whatsapp::MessageTemplate.where(channel_id: channel.id).order(:name, :language)
  end

  private

  def fetch_remote_templates
    Whatsapp::Account::Templates
      .new(**channel.options.slice(:business_id, :access_token).symbolize_keys)
      .list
  end

  def upsert_template(template_data)
    record = Whatsapp::MessageTemplate.find_or_initialize_by(
      channel_id: channel.id,
      name:       template_data[:name],
      language:   template_data[:language],
    )

    components = normalize_components(template_data[:components])
    variables  = Whatsapp::MessageTemplate.parse_variables_from_components(components)

    record.assign_attributes(
      status:           template_data[:status],
      category:         template_data[:category],
      meta_template_id: template_data[:meta_template_id]&.to_s,
      components:       components,
      variables:        variables,
    )

    record.save!
  end

  def normalize_components(components)
    Array(components).map do |component|
      component.respond_to?(:to_h) ? component.to_h : component
    end
  end
end
