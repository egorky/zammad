# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Whatsapp::MessageTemplate < ApplicationModel
  self.table_name = 'whatsapp_message_templates'

  belongs_to :channel, class_name: 'Channel'

  validates :name, :language, :channel_id, presence: true
  validates :name, uniqueness: { scope: %i[channel_id language] }

  def self.parse_variables_from_components(components)
    result = {
      body:    [],
      header:  [],
      buttons: [],
    }

    Array(components).each do |component|
      component = component.deep_symbolize_keys
      type      = component[:type].to_s.upcase

      case type
      when 'BODY'
        result[:body] = extract_placeholders(component[:text])
      when 'HEADER'
        next if component[:format] != 'TEXT'

        result[:header] = extract_placeholders(component[:text])
      when 'BUTTONS'
        Array(component[:buttons]).each_with_index do |button, index|
          next if button[:type] != 'URL'

          placeholders = extract_placeholders(button[:url])
          result[:buttons][index] = placeholders if placeholders.present?
        end
      end
    end

    result
  end

  def self.extract_placeholders(text)
    return [] if text.blank?

    placeholders = text.scan(/\{\{(\d+)\}\}/).flatten.map(&:to_i).uniq.sort
    placeholders.map { |position| { position:, label: "Variable #{position}" } }
  end

  def body_preview(values = [])
    body_component = Array(components).find { |c| c['type'].to_s.upcase == 'BODY' }
    return '' if body_component.blank?

    text = body_component['text'].to_s
    Array(values).each_with_index do |value, index|
      text = text.gsub("{{#{index + 1}}}", value.to_s)
    end
    text
  end

  def build_components_json(variable_values)
    variable_values = variable_values.deep_symbolize_keys
    components_json = []

    Array(components).each do |component|
      component = component.deep_symbolize_keys
      type      = component[:type].to_s.downcase

      case type
      when 'body'
        parameters = build_text_parameters(variable_values[:body])
        components_json << { 'type' => 'body', 'parameters' => parameters } if parameters.present?
      when 'header'
        next if component[:format] != 'TEXT'

        parameters = build_text_parameters(variable_values[:header])
        components_json << { 'type' => 'header', 'parameters' => parameters } if parameters.present?
      when 'buttons'
        Array(component[:buttons]).each_with_index do |button, index|
          next if button[:type] != 'URL'

          parameters = build_text_parameters(variable_values.dig(:buttons, index))
          next if parameters.blank?

          components_json << {
            'type'       => 'button',
            'sub_type'   => 'url',
            'index'      => index.to_s,
            'parameters' => parameters,
          }
        end
      end
    end

    components_json
  end

  def self.build_text_parameters(values)
    Array(values).filter_map do |value|
      next if value.blank?

      { 'type' => 'text', 'text' => value.to_s }
    end
  end
  private_class_method :build_text_parameters

  private

  def build_text_parameters(values)
    self.class.build_text_parameters(values)
  end
end
