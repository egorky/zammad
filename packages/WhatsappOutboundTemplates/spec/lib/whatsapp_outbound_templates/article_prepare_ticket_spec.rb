# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe WhatsappOutboundTemplates::ArticlePrepareTicket do
  let(:channel) { create(:whatsapp_channel) }
  let(:customer) { create(:user, mobile: '+4917012345678') }
  let(:agent) { create(:agent, groups: [channel.group]) }
  let(:ticket) { create(:ticket, group: channel.group, customer: customer, preferences: {}) }

  before do
    UserInfo.current_user_id = agent.id
  end

  it 'sets ticket preferences when creating a whatsapp template article via REST flow' do
    create(
      :ticket_article,
      ticket:      ticket,
      type_name:   'whatsapp template message',
      sender_name: 'Agent',
      created_by:  agent,
      preferences: {
        whatsapp_template: {
          name:       'hello_world',
          language:   'en_US',
          channel_id: channel.id,
        },
      },
    )

    expect(ticket.reload.preferences).to include(
      'channel_id' => channel.id,
      'whatsapp'   => include(
        'from' => include('phone_number' => '4917012345678'),
      ),
    )
  end
end
