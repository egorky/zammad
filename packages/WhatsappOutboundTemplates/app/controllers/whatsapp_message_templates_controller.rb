# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class WhatsappMessageTemplatesController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    channel = resolve_channel
    raise Exceptions::UnprocessableContent, __('WhatsApp channel could not be resolved.') if channel.blank?

    templates = Service::Whatsapp::Templates::List.execute(
      channel_id: channel.id,
      status:     params[:status],
    )

    render json: templates.map { |template| template_as_json(template) }
  end

  def sync
    channel = resolve_channel
    raise Exceptions::UnprocessableContent, __('WhatsApp channel could not be resolved.') if channel.blank?

    templates = Service::Whatsapp::Templates::Sync.execute(
      channel_id: channel.id,
    )

    render json: {
      message:   __('WhatsApp templates synchronized successfully.'),
      templates: templates.map { |template| template_as_json(template) },
    }
  end

  private

  def resolve_channel
    if params[:channel_id].present?
      return Channel.in_area('WhatsApp::Business').find_by(id: params[:channel_id])
    end

    return if params[:group_id].blank?

    Channel.in_area('WhatsApp::Business').find_by(group_id: params[:group_id], active: true)
  end

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
