# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  api_path = Rails.configuration.api_path

  scope api_path do
    resources :whatsapp_message_templates,
              controller: 'whatsapp_message_templates',
              path:       'whatsapp_message_templates',
              only:       %i[index] do
      collection do
        get  :channel_groups
        post :sync
      end
    end
  end
end
