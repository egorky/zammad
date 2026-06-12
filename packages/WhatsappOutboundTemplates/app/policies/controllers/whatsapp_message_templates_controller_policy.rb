# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::WhatsappMessageTemplatesControllerPolicy < Controllers::ApplicationControllerPolicy
  def index?
    agent_access?
  end

  def sync?
    sync_permission?
  end

  private

  def agent_access?
    user.permissions?('ticket.agent')
  end

  def sync_permission?
    user.permissions?('admin.channel_whatsapp') || user.permissions?('ticket.agent')
  end
end
