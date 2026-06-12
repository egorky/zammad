# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Whatsapp::MessageTemplate, type: :model do
  describe '.parse_variables_from_components' do
    it 'extracts body placeholders' do
      components = [
        {
          'type' => 'BODY',
          'text' => 'Hello {{1}}, your order {{2}} is ready.',
        },
      ]

      variables = described_class.parse_variables_from_components(components)

      expect(variables[:body].pluck(:position)).to eq([1, 2])
    end
  end

  describe '#build_components_json' do
    let(:template) do
      described_class.new(
        components: [
          { 'type' => 'BODY', 'text' => 'Hello {{1}}' },
        ],
        variables:  {
          'body' => [{ 'position' => 1, 'label' => 'Variable 1' }],
        },
      )
    end

    it 'builds body parameters' do
      result = template.build_components_json({ body: ['Jane'] })

      expect(result).to eq([
                             {
                               'type'       => 'body',
                               'parameters' => [{ 'type' => 'text', 'text' => 'Jane' }],
                             },
                           ])
    end
  end
end
