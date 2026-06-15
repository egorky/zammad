# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Whatsapp::Account::Templates do
  subject(:templates) do
    described_class.new(access_token: 'token', business_id: '12345')
  end

  let(:templates_api) { instance_double(WhatsappSdk::Api::Templates) }

  before do
    allow(WhatsappSdk::Api::Templates).to receive(:new).and_return(templates_api)
    allow(templates_api).to receive(:send_request).and_return(api_response)
  end

  let(:api_response) do
    {
      'data' => [
        {
          'id'         => '999',
          'name'       => 'hello_world',
          'language'   => 'en_US',
          'status'     => 'APPROVED',
          'category'   => 'UTILITY',
          'components' => [{ 'type' => 'BODY', 'text' => 'Hello {{1}}' }],
        },
      ],
      'paging' => {
        'cursors' => {
          'after' => nil,
        },
      },
    }
  end

  describe '#list' do
    it 'maps templates from the paginated API response' do
      result = templates.list

      expect(result).to eq([
                             {
                               meta_template_id: '999',
                               name:             'hello_world',
                               language:         'en_US',
                               status:           'APPROVED',
                               category:         'UTILITY',
                               components:       [{ type: 'BODY', text: 'Hello {{1}}' }],
                             },
                           ])
    end

    it 'fetches additional pages when a cursor is present' do
      allow(templates_api).to receive(:send_request).and_return(
        {
          'data' => [
            {
              'id'         => '1',
              'name'       => 'first',
              'language'   => 'en_US',
              'status'     => 'APPROVED',
              'category'   => 'UTILITY',
              'components' => [],
            },
          ],
          'paging' => { 'cursors' => { 'after' => 'cursor-2' } },
        },
        {
          'data' => [
            {
              'id'         => '2',
              'name'       => 'second',
              'language'   => 'en_US',
              'status'     => 'APPROVED',
              'category'   => 'UTILITY',
              'components' => [],
            },
          ],
          'paging' => { 'cursors' => { 'after' => nil } },
        },
      )

      result = templates.list

      expect(result.pluck(:name)).to eq(%w[first second])
      expect(templates_api).to have_received(:send_request).twice
    end
  end
end
