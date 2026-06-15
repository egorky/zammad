# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe WhatsappOutboundTemplates::Preferences do
  let(:channel) { create(:whatsapp_channel) }
  let(:customer) { create(:user, mobile: '+49 170 1234567') }
  let(:ticket) { create(:ticket, group: channel.group, customer: customer, preferences: {}) }

  describe '.apply_to_ticket!' do
    let(:article) do
      build(
        :ticket_article,
        ticket:      ticket,
        type_name:   'whatsapp template message',
        sender_name: 'Agent',
        preferences: {
          whatsapp_template: {
            name:        'hello_world',
            language:    'en_US',
            channel_id:  channel.id,
          },
        },
      )
    end

    it 'stores channel and recipient data on the ticket' do
      described_class.apply_to_ticket!(ticket, article: article)

      expect(ticket.reload.preferences).to include(
        'channel_id'   => channel.id,
        'channel_area' => channel.area,
        'whatsapp'     => include(
          'from' => include(
            'phone_number' => '491701234567',
          ),
        ),
      )
    end
  end

  describe '.whatsapp_template_article?' do
    it 'detects template articles by type_id' do
      type = Ticket::Article::Type.lookup(name: 'whatsapp template message')

      expect(described_class.whatsapp_template_article?({ type_id: type.id })).to be(true)
      expect(described_class.whatsapp_template_article?({ type_id: Ticket::Article::Type.lookup(name: 'note').id })).to be(false)
    end

    it 'detects template articles by whatsapp_template preferences' do
      expect(described_class.whatsapp_template_article?({
                                                          preferences: {
                                                            whatsapp_template: {
                                                              name: 'hello_world',
                                                            },
                                                          },
                                                        })).to be(true)
    end
  end
end
