# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'WhatsApp template ticket create via REST', type: :request do
  let(:channel) { create(:whatsapp_channel) }
  let(:customer) { create(:user, mobile: '+593999989522') }
  let(:agent) { create(:agent, groups: [channel.group]) }
  let(:template_type) { Ticket::Article::Type.lookup(name: 'whatsapp template message') }
  let(:whatsapp_type) { Ticket::Article::Type.lookup(name: 'whatsapp message') }

  let(:ticket_params) do
    {
      title:       'hello_world',
      group_id:    channel.group_id,
      customer_id: customer.id,
      article:     {
        body:        'Hello',
        type_id:     template_type.id,
        sender_id:   Ticket::Article::Sender.lookup(name: 'Agent').id,
        content_type: 'text/plain',
        preferences: {
          whatsapp_template: {
            name:       'hello_world',
            language:   'en_US',
            channel_id: channel.id,
          },
        },
      },
    }
  end

  before do
    authenticated_as(agent)
  end

  it 'reuses an open whatsapp ticket instead of creating a duplicate' do
    existing_ticket = create(:whatsapp_ticket, channel: channel, customer: customer)

    expect do
      post '/api/v1/tickets', params: ticket_params, as: :json
    end.not_to change(Ticket, :count)

    expect(response).to have_http_status(:created)
    expect(json_response['id']).to eq(existing_ticket.id)
    expect(existing_ticket.reload.articles.where(type_id: template_type.id).count).to eq(1)
  end

  it 'marks new whatsapp template tickets as whatsapp conversations' do
    post '/api/v1/tickets', params: ticket_params, as: :json

    expect(response).to have_http_status(:created)

    ticket = Ticket.find(json_response['id'])
    expect(ticket.create_article_type_id).to eq(whatsapp_type.id)
    expect(ticket.preferences).to include('channel_id' => channel.id)
  end
end
