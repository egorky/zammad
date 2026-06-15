// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { computed, type Ref } from 'vue'

import type { TicketArticle } from '#shared/entities/ticket/types.ts'

export type WhatsappDeliveryState = 'read' | 'delivered' | 'sent' | 'failed'

export const useWhatsappArticleDelivery = (article: Ref<TicketArticle>) => {
  const deliveryFailed = computed(() => {
    const preferences = article.value.preferences

    return (
      preferences?.delivery_status === 'fail' || preferences?.whatsapp?.delivery_status === 'fail'
    )
  })

  const failureMessage = computed(() => {
    const preferences = article.value.preferences

    return preferences?.delivery_status_message || preferences?.whatsapp?.delivery_status_message
  })

  const articleDeliveryStatus = computed(() => {
    const whatsapp = article.value.preferences?.whatsapp

    if (!whatsapp) return undefined

    if (whatsapp.timestamp_read) {
      return {
        message: __('read by the customer'),
        icon: 'read',
        state: 'read' as WhatsappDeliveryState,
      }
    }

    if (whatsapp.timestamp_delivered) {
      return {
        message: __('delivered to the customer'),
        icon: 'delivered',
        state: 'delivered' as WhatsappDeliveryState,
      }
    }

    if (whatsapp.timestamp_sent || whatsapp.message_id) {
      return {
        message: __('sent to the customer'),
        icon: 'send',
        state: 'sent' as WhatsappDeliveryState,
      }
    }

    return undefined
  })

  const hasDeliveryStatus = computed(() => Boolean(articleDeliveryStatus.value))

  return {
    articleDeliveryStatus,
    deliveryFailed,
    failureMessage,
    hasDeliveryStatus,
  }
}
