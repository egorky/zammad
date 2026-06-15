<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, toRef } from 'vue'

import { useWhatsapp } from '#shared/entities/ticket/channel/composables/useWhatsapp.ts'
import type { TicketArticle } from '#shared/entities/ticket/types.ts'
import { EnumTicketArticleSenderName } from '#shared/graphql/types.ts'

interface Props {
  article: TicketArticle
}

const props = defineProps<Props>()

const { articleDeliveryStatus, hasDeliveryStatus } = useWhatsapp(toRef(props, 'article'))

const WHATSAPP_ARTICLE_TYPES = ['whatsapp message', 'whatsapp template message']

const isWhatsappOutboundArticle = computed(() => {
  const typeName = props.article.type?.name
  const isWhatsappType = typeName ? WHATSAPP_ARTICLE_TYPES.includes(typeName) : false

  return isWhatsappType && props.article.sender?.name === EnumTicketArticleSenderName.Agent
})

const deliveryFailed = computed(() => {
  const preferences = props.article.preferences

  return (
    preferences?.delivery_status === 'fail' || preferences?.whatsapp?.delivery_status === 'fail'
  )
})

const failureMessage = computed(() => {
  const preferences = props.article.preferences

  return preferences?.delivery_status_message || preferences?.whatsapp?.delivery_status_message
})

const showStatus = computed(
  () =>
    isWhatsappOutboundArticle.value &&
    (hasDeliveryStatus.value || deliveryFailed.value || Boolean(props.article.preferences?.whatsapp?.message_id)),
)
</script>

<template>
  <div v-if="showStatus" class="flex flex-col gap-1 border-t border-neutral-300 px-3 py-2 dark:border-neutral-500">
    <div
      v-if="deliveryFailed"
      class="flex items-start gap-2 rounded-md bg-red-100 px-2 py-1.5 text-xs text-red-900 dark:bg-red-900/30 dark:text-red-100"
      role="alert"
    >
      <CommonIcon name="warning" size="tiny" />
      <div>
        <div class="font-semibold">{{ $t('Delivery failed') }}</div>
        <div v-if="failureMessage">{{ failureMessage }}</div>
      </div>
    </div>
    <div v-else class="flex items-center justify-end gap-1.5 text-xs text-neutral-600 dark:text-neutral-300">
      <CommonIcon
        v-if="articleDeliveryStatus?.icon"
        width="14"
        height="14"
        :name="articleDeliveryStatus.icon"
      />
      <span>{{ articleDeliveryStatus?.message }}</span>
    </div>
  </div>
</template>
