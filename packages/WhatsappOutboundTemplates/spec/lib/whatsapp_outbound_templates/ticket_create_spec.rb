# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe WhatsappOutboundTemplates::TicketCreate do
  let(:channel) { create(:whatsapp_channel) }
  let(:customer) { create(:user, mobile: '+49 170 1234567') }
  let(:agent) { create(:agent, groups: [channel.group]) }

  let(:ticket_data) do
    {
      title:    'Outbound WhatsApp',
      group:    channel.group,
      customer: customer,
      article:  {
        body:   'Hello Jane',
        sender: 'Agent',
        type:   'whatsapp template message',
        preferences: {
          whatsapp_template: {
            name:     'hello_world',
            language: 'en_US',
          },
        },
      },
    }
  end

  before do
    UserInfo.current_user_id = agent.id
  end

  it 'sets whatsapp ticket preferences before creating the ticket' do
    ticket = Service::Ticket::Create.execute(ticket_data: ticket_data)

    expect(ticket.preferences).to include(
      'channel_id'   => channel.id,
      'channel_area' => channel.area,
      'whatsapp'     => include(
        'from' => include(
          'phone_number' => '491701234567',
        ),
      ),
    )
  end

  it 'reuses an open whatsapp ticket for the same customer and channel' do
    existing_ticket = create(:whatsapp_ticket, channel: channel, customer: customer)

    ticket = Service::Ticket::Create.execute(ticket_data: ticket_data)

    expect(ticket.id).to eq(existing_ticket.id)
    expect(ticket.articles.where(type: Ticket::Article::Type.lookup(name: 'whatsapp template message')).count).to eq(1)
  end
end
