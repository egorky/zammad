# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Service::Whatsapp::Templates::List do
  subject(:service_result) { described_class.execute(channel_id: channel.id, status: 'APPROVED') }

  let(:channel) { create(:whatsapp_channel) }

  before do
    Whatsapp::MessageTemplate.create!(
      channel_id: channel.id,
      name:       'hello_world',
      language:   'en_US',
      status:     'APPROVED',
      components: [],
      variables:  {},
    )
    Whatsapp::MessageTemplate.create!(
      channel_id: channel.id,
      name:       'draft_tpl',
      language:   'en_US',
      status:     'DRAFT',
      components: [],
      variables:  {},
    )
  end

  it 'returns approved templates for the channel' do
    expect(service_result.map(&:name)).to eq(['hello_world'])
  end
end
