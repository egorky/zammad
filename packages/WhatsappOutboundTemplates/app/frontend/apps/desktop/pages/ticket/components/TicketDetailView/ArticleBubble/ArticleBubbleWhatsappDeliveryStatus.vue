<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, toRef } from 'vue'

import { useWhatsappArticleDelivery } from '#shared/composables/useWhatsappArticleDelivery.ts'
import type { TicketArticle } from '#shared/entities/ticket/types.ts'
import { EnumTicketArticleSenderName } from '#shared/graphql/types.ts'

interface Props {
  article: TicketArticle
}

const props = defineProps<Props>()

const { articleDeliveryStatus, deliveryFailed, failureMessage, hasDeliveryStatus } =
  useWhatsappArticleDelivery(toRef(props, 'article'))

const WHATSAPP_ARTICLE_TYPES = ['whatsapp message', 'whatsapp template message']

const isWhatsappOutboundArticle = computed(() => {
  const typeName = props.article.type?.name
  const isWhatsappType = typeName ? WHATSAPP_ARTICLE_TYPES.includes(typeName) : false

  return isWhatsappType && props.article.sender?.name === EnumTicketArticleSenderName.Agent
})

const showStatus = computed(
  () => isWhatsappOutboundArticle.value && (hasDeliveryStatus.value || deliveryFailed.value),
)

const statusColorClass = computed(() => {
  const state = articleDeliveryStatus.value?.state

  if (state === 'read') return 'text-sky-500'
  if (state === 'delivered' || state === 'sent') return 'text-neutral-500 dark:text-neutral-400'

  return 'text-neutral-600 dark:text-neutral-300'
})
</script>

<template>
  <div
    v-if="showStatus"
    class="flex flex-col gap-1 px-3 pb-2"
  >
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
    <div
      v-else
      class="flex items-center justify-end gap-1.5 text-xs"
      :class="statusColorClass"
    >
      <CommonIcon
        v-if="articleDeliveryStatus?.icon"
        width="14"
        height="14"
        :name="articleDeliveryStatus.icon"
        :class="statusColorClass"
      />
      <span>{{ articleDeliveryStatus?.message }}</span>
    </div>
  </div>
</template>
