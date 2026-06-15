# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CreateWhatsappMessageTemplates
  def self.up
    connection = ActiveRecord::Base.connection
    return if connection.table_exists?(:whatsapp_message_templates)

    connection.create_table :whatsapp_message_templates, id: :integer do |t|
      t.integer :channel_id, null: false
      t.string  :name, null: false
      t.string  :language, null: false
      t.string  :status
      t.string  :category
      t.string  :meta_template_id
      t.json    :components
      t.json    :variables
      t.timestamps limit: 3, null: false
    end

    connection.add_index :whatsapp_message_templates, %i[channel_id name language], unique: true, name: 'index_whatsapp_message_templates_on_channel_name_language'
    connection.add_index :whatsapp_message_templates, :channel_id
  end

  def self.down
    connection = ActiveRecord::Base.connection
    connection.drop_table :whatsapp_message_templates, if_exists: true
  end
end
