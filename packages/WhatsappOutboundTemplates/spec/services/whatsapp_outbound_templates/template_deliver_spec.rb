# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe WhatsappOutboundTemplates::TemplateDeliver do
  subject(:service_result) { described_class.execute(article_id: article.id) }

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
end
