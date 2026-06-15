# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe CoreWorkflow::Custom::WhatsappTemplateTicketCreate, type: :model do
  let(:agent) { create(:agent) }

  def perform_workflow(params, last_changed_attribute: nil)
    CoreWorkflow.perform(
      payload: {
        'event'                  => 'core_workflow',
        'class_name'             => 'Ticket',
        'screen'                 => 'create_middle',
        'params'                 => params,
        'last_changed_attribute' => last_changed_attribute,
      },
      user:    agent,
      assets:  false,
    )
  end

  it 'hides title, body and attachments for whatsapp template ticket create' do
    result = perform_workflow(
      {
        'articleSenderType' => 'whatsapp-template-out',
        'group_id'          => '1',
      },
      last_changed_attribute: 'articleSenderType',
    )

    expect(result[:visibility]['title']).to eq('hide')
    expect(result[:visibility]['body']).to eq('hide')
    expect(result[:visibility]['attachments']).to eq('hide')
    expect(result[:mandatory]['title']).to eq('false')
    expect(result[:mandatory]['body']).to eq('false')
  end

  it 'shows title and body again for other ticket create types' do
    result = perform_workflow(
      {
        'articleSenderType' => 'email-out',
        'group_id'          => '1',
      },
      last_changed_attribute: 'articleSenderType',
    )

    expect(result[:visibility]['title']).to eq('show')
    expect(result[:visibility]['body']).to eq('show')
    expect(result[:visibility]['attachments']).to eq('show')
    expect(result[:mandatory]['title']).to eq('true')
    expect(result[:mandatory]['body']).to eq('true')
  end
end
