# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class WhatsappMessageTemplatesController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    raise Exceptions::UnprocessableContent, __('The required parameter \'channel_id\' is missing.') if params[:channel_id].blank?

    templates = Service::Whatsapp::MessageTemplate::List.execute(
      channel_id: params[:channel_id],
      status:     params[:status],
    )

    render json: templates.map { |template| template_as_json(template) }
  end

  def sync
    raise Exceptions::UnprocessableContent, __('The required parameter \'channel_id\' is missing.') if params[:channel_id].blank?

    templates = Service::Whatsapp::MessageTemplate::Sync.execute(
      channel_id: params[:channel_id],
    )

    render json: {
      message:   __('WhatsApp templates synchronized successfully.'),
      templates: templates.map { |template| template_as_json(template) },
    }
  end

  private

  def template_as_json(template)
    {
      id:               template.id,
      channel_id:       template.channel_id,
      name:             template.name,
      language:         template.language,
      status:           template.status,
      category:         template.category,
      meta_template_id: template.meta_template_id,
      components:       template.components,
      variables:        template.variables,
      updated_at:       template.updated_at,
      created_at:       template.created_at,
    }
  end
end
