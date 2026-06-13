# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe WhatsappMessageTemplatesController, type: :request do
  let(:channel) { create(:whatsapp_channel) }
  let(:agent) { create(:agent, groups: [channel.group]) }

  before do
    Whatsapp::MessageTemplate.create!(
      channel_id: channel.id,
      name:       'hello_world',
      language:   'en_US',
      status:     'APPROVED',
      components: [],
      variables:  {},
    )
  end

  describe 'GET /api/v1/whatsapp_message_templates' do
    it 'returns templates by channel_id' do
      authenticated_as(agent)

      get "/api/v1/whatsapp_message_templates", params: {
        channel_id: channel.id,
        status:     'APPROVED',
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.pluck('name')).to eq(['hello_world'])
    end

    it 'returns an empty list when group has no WhatsApp channel' do
      authenticated_as(agent)

      get "/api/v1/whatsapp_message_templates", params: {
        group_id: 999_999,
        status:   'APPROVED',
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq([])
    end
  end

  describe 'GET /api/v1/whatsapp_message_templates/channel_groups' do
    it 'returns WhatsApp channel groups for agents' do
      authenticated_as(agent)

      get '/api/v1/whatsapp_message_templates/channel_groups', as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to contain_exactly(
        include(
          'channel_id' => channel.id,
          'group_id'   => channel.group_id,
          'group_name' => channel.group.name,
          'active'     => true,
        )
      )
    end
  end

  describe 'POST /api/v1/whatsapp_message_templates/sync' do
    it 'syncs templates for the given channel' do
      authenticated_as(agent)

      allow_any_instance_of(Whatsapp::Account::Templates).to receive(:list).and_return(
        [
          {
            meta_template_id: '123',
            name:             'hello_world',
            language:         'en_US',
            status:           'APPROVED',
            category:         'UTILITY',
            components:       [{ type: 'BODY', text: 'Hello {{1}}' }],
          },
        ]
      )

      post "/api/v1/whatsapp_message_templates/sync", params: {
        channel_id: channel.id,
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['count']).to eq(1)
      expect(json_response['templates'].pluck('name')).to eq(['hello_world'])
    end
  end
end
