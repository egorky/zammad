# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class WhatsappMessageTemplatesController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    channel = resolve_channel
    return render json: [] if channel.blank?

    templates = Service::Channel::Whatsapp::TemplateList.new(
      channel_id: channel.id,
      status:     params[:status],
    ).execute

    render json: templates.map { |template| template_as_json(template) }
  end

  def sync
    channel = resolve_channel
    raise Exceptions::UnprocessableContent, __('WhatsApp channel could not be resolved.') if channel.blank?

    templates = Service::Channel::Whatsapp::TemplateSync.new(
      channel_id: channel.id,
    ).execute

    template_payload = templates.map { |template| template_as_json(template) }

    render json: {
      message:   sync_message(template_payload),
      count:     template_payload.length,
      templates: template_payload,
    }
  end

  def channel_groups
    channels = Channel.in_area('WhatsApp::Business').order(:group_id, :id)

    render json: channels.map { |channel| channel_group_as_json(channel) }
  end

  private

  def resolve_channel
    channel_id = params[:channel_id].presence
    if channel_id.present?
      return Channel.in_area('WhatsApp::Business').find_by(id: channel_id)
    end

    group_id = params[:group_id].presence
    return if group_id.blank?

    Channel.in_area('WhatsApp::Business').find_by(group_id: group_id, active: true) ||
      Channel.in_area('WhatsApp::Business').find_by(group_id: group_id)
  end

  def sync_message(templates)
    return __('No templates were found in your Meta account.') if templates.blank?

    __('%{count} WhatsApp templates synchronized successfully.', count: templates.length)
  end

  def channel_group_as_json(channel)
    {
      channel_id: channel.id,
      group_id:   channel.group_id,
      group_name: channel.group&.name,
      active:     channel.active,
    }
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
