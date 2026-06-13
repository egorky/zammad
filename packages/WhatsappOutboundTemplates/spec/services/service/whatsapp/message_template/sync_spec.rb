# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Service::Whatsapp::Templates::Sync do
  subject(:service_result) { described_class.execute(channel_id: channel.id) }

  let(:channel) { create(:whatsapp_channel) }

  let(:remote_templates) do
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
  end

  before do
    allow_any_instance_of(Whatsapp::Account::Templates).to receive(:list).and_return(remote_templates)
  end

  it 'stores templates for the channel' do
    expect { service_result }.to change(Whatsapp::MessageTemplate, :count).by(1)

    template = Whatsapp::MessageTemplate.last
    expect(template).to have_attributes(
      channel_id: channel.id,
      name:       'hello_world',
      language:   'en_US',
      status:     'APPROVED',
    )
  end
end
