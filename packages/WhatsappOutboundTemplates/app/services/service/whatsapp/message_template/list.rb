# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Service::Whatsapp::MessageTemplate::List < Service::Base
  attr_reader :channel_id, :status

  def initialize(channel_id:, status: nil)
    @channel_id = channel_id
    @status     = status
  end

  def execute
    scope = Whatsapp::MessageTemplate.where(channel_id: channel_id)
    scope = scope.where(status: status) if status.present?

    scope.order(:name, :language)
  end
end
