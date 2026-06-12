// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { setupView } from '#tests/support/mock-user.ts'

import { EnumChannelArea } from '#shared/graphql/types.ts'

import { createTestArticleTypes, createTicket } from './utils.ts'

const createWhatsappTicket = () => {
  return createTicket({
    policy: { update: true, agentReadAccess: true },
    initialChannel: EnumChannelArea.WhatsAppBusiness,
    createArticleType: { name: 'whatsapp message' },
    preferences: {
      channel_id: 1,
      whatsapp: {
        from: {
          phone_number: '1234567890',
        },
      },
    },
  })
}

describe('whatsapp template article type', () => {
  it('is available for whatsapp tickets', () => {
    setupView('agent')

    const ticket = createWhatsappTicket()
    const types = createTestArticleTypes(ticket)
    const templateType = types.find((type) => type.value === 'whatsapp template message')

    expect(templateType?.label).toBe('WhatsApp Template')
    expect(templateType?.buttonLabel).toBe('Send template')
  })

  it('is not available for non-whatsapp tickets', () => {
    setupView('agent')

    const ticket = createTicket({
      policy: { update: true, agentReadAccess: true },
      createArticleType: { name: 'email' },
    })

    const types = createTestArticleTypes(ticket)
    const templateType = types.find((type) => type.value === 'whatsapp template message')

    expect(templateType).toBeUndefined()
  })
})
