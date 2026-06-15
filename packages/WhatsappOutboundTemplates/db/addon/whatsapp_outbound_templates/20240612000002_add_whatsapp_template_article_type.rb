# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddWhatsappTemplateArticleType
  def self.up
    Ticket::Article::Type.create_if_not_exists(
      name:          'whatsapp template message',
      communication: true,
      updated_by_id: 1,
      created_by_id: 1,
    )
  end

  def self.down
    Ticket::Article::Type.find_by(name: 'whatsapp template message')&.destroy
  end
end
