// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { computed } from 'vue'

import type { FormFieldAdditionalProps } from '#shared/components/Form/types.ts'
import { useAppName } from '#shared/composables/useAppName.ts'
import { useApplicationStore } from '#shared/stores/application.ts'

import { TicketCreateArticleType } from '../types.ts'

const WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'

export const ticketCreateArticleType = {
  [TicketCreateArticleType.PhoneIn]: {
    icon: 'phone-in',
    label: __('Received call'),
    title: __('Received call: %s'),
    sender: 'Customer',
    type: 'phone',
  },
  [TicketCreateArticleType.PhoneOut]: {
    icon: 'phone-out',
    label: __('Outbound call'),
    title: __('Outbound call: %s'),
    sender: 'Agent',
    type: 'phone',
  },
  [TicketCreateArticleType.EmailOut]: {
    icon: 'mail-out',
    label: __('Send email'),
    title: __('Send email: %s'),
    sender: 'Agent',
    type: 'email',
  },
  [WHATSAPP_TEMPLATE_CREATE_TYPE]: {
    icon: 'whatsapp',
    label: __('WhatsApp template'),
    title: __('WhatsApp template: %s'),
    sender: 'Agent',
    type: 'whatsapp template message',
  },
}

type TicketCreateArticleTypeValue = keyof typeof ticketCreateArticleType

export const useTicketCreateArticleType = (additionalProps: FormFieldAdditionalProps = {}) => {
  const application = useApplicationStore()

  const availableTypes = computed(() => {
    let configuredAvailableTypes =
      (application.config.ui_ticket_create_available_types as
        | TicketCreateArticleTypeValue[]
        | TicketCreateArticleTypeValue) || []

    if (!Array.isArray(configuredAvailableTypes)) {
      configuredAvailableTypes = [configuredAvailableTypes]
    }

    return configuredAvailableTypes.filter((availableType) => availableType in ticketCreateArticleType)
  })

  const options = computed(() => {
    return availableTypes.value.map((availableType) => ({
      label: ticketCreateArticleType[availableType].label,
      value: availableType,
      icon: ticketCreateArticleType[availableType].icon,
    }))
  })

  const defaultTicketCreateArticleType = application.config
    .ui_ticket_create_default_type as TicketCreateArticleTypeValue

  const ticketArticleSenderTypeField = {
    name: 'articleSenderType',
    type: useAppName() === 'mobile' ? 'radio' : 'toggleButtons',
    required: true,
    value: availableTypes.value.includes(defaultTicketCreateArticleType)
      ? defaultTicketCreateArticleType
      : availableTypes.value[0],
    props: {
      options,
      ...additionalProps,
    },
  }

  return {
    ticketCreateArticleType,
    ticketArticleSenderTypeField,
    defaultTicketCreateArticleType,
  }
}
