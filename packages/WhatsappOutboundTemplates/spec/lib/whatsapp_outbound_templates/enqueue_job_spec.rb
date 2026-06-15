# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe WhatsappOutboundTemplates::EnqueueJob, performs_jobs: true do
  let(:channel) { create(:whatsapp_channel) }
  let(:customer) { create(:user, mobile: '+4917012345678') }
  let(:agent) { create(:agent, groups: [channel.group]) }
  let(:ticket) do
    create(
      :ticket,
      group:       channel.group,
      customer:    customer,
      preferences: {
        channel_id: channel.id,
        whatsapp:   {
          from: {
            phone_number: '4917012345678',
          },
        },
      },
    )
  end

  before do
    UserInfo.current_user_id = agent.id
  end

  it 'enqueues delivery for whatsapp template articles' do
    expect do
      create(
        :ticket_article,
        ticket:      ticket,
        type_name:   'whatsapp template message',
        sender_name: 'Agent',
        created_by:  agent,
        preferences: {
          whatsapp_template: {
            name:     'hello_world',
            language: 'en_US',
          },
        },
      )
    end.to have_enqueued_job(CommunicateWhatsappTemplateJob)
  end

  it 'enqueues delivery when template preferences are present without article type' do
    expect do
      create(
        :ticket_article,
        ticket:      ticket,
        type_name:   'note',
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
    end.to have_enqueued_job(CommunicateWhatsappTemplateJob)
  end
end
