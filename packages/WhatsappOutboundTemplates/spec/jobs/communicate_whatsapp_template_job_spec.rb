# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe CommunicateWhatsappTemplateJob::Deliver do
  subject(:service_result) { described_class.new(article_id: article.id).execute }

  let(:article) do
    create(
      :whatsapp_article,
      :pending_delivery,
      preferences: {
        whatsapp_template: {
          name:            'hello_world',
          language:        'en_US',
          components_json: [{ type: 'body', parameters: [{ type: 'text', text: 'Jane' }] }],
        },
      },
    )
  end

  let(:message_id) { "wamid.#{Faker::Crypto.unique.sha1}==" }

  before do
    article
    allow_any_instance_of(Whatsapp::Outgoing::Message::Template).to receive(:deliver).and_return({ id: message_id })
  end

  it 'delivers the template message' do
    expect(service_result).to have_attributes(
      message_id:  message_id,
      preferences: include(
        delivery_status: 'success',
        whatsapp:        include(message_id: message_id),
      ),
    )
  end

  it 'inherits BaseDeliver execute behavior' do
    expect(described_class.ancestors).to include(Service::Ticket::Article::Type::BaseDeliver)
    expect(described_class.new(article_id: article.id)).to respond_to(:execute)
  end

  context 'when the ticket was created without channel preferences' do
    let(:channel) { create(:whatsapp_channel) }
    let(:customer) { create(:user, mobile: '+4917012345678') }
    let(:ticket) { create(:ticket, group: channel.group, customer: customer, preferences: {}) }
    let(:article) do
      create(
        :ticket_article,
        ticket:      ticket,
        type_name:   'whatsapp template message',
        sender_name: 'Agent',
        preferences: {
          whatsapp_template: {
            name:       'hello_world',
            language:   'en_US',
            channel_id: channel.id,
          },
        },
      )
    end

    before do
      article
      allow_any_instance_of(Whatsapp::Outgoing::Message::Template).to receive(:deliver).and_return({ id: message_id })
    end

    it 'backfills ticket preferences before delivery' do
      expect(service_result.ticket.reload.preferences).to include('channel_id' => channel.id)
    end
  end
end

RSpec.describe CommunicateWhatsappTemplateJob do
  subject(:perform_job) { described_class.perform_now(article.id) }

  let(:article) do
    create(
      :whatsapp_article,
      :pending_delivery,
      preferences: {
        whatsapp_template: {
          name:     'hello_world',
          language: 'en_US',
        },
      },
    )
  end

  let(:message_id) { "wamid.#{Faker::Crypto.unique.sha1}==" }

  before do
    article
    allow_any_instance_of(Whatsapp::Outgoing::Message::Template).to receive(:deliver).and_return({ id: message_id })
  end

  it 'runs delivery through the nested deliver class' do
    expect { perform_job }.not_to raise_error

    article.reload
    expect(article.preferences).to include(
      'delivery_status' => 'success',
      'whatsapp'        => include('message_id' => message_id),
    )
  end
end
