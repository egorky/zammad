<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, toRef } from 'vue'

import { useWhatsappArticleDelivery } from '#shared/composables/useWhatsappArticleDelivery.ts'
import type { TicketArticle } from '#shared/entities/ticket/types.ts'

interface Props {
  context: {
    article: TicketArticle
  }
}

const props = defineProps<Props>()

const { articleDeliveryStatus, deliveryFailed, failureMessage } = useWhatsappArticleDelivery(
  toRef(props.context, 'article'),
)

const articleTypeLabel = computed(() => {
  if (props.context.article.type?.name === 'whatsapp template message') {
    return __('whatsapp template message')
  }

  return __('whatsapp message')
})

const statusColorClass = computed(() => {
  const state = articleDeliveryStatus.value?.state

  if (state === 'read') return 'text-sky-500'
  if (state === 'delivered' || state === 'sent') return 'text-neutral-500 dark:text-neutral-400'

  return ''
})
</script>

<template>
  <div class="flex items-center gap-1.5">
    <CommonIcon
      text-neutral-950
      class="text-black! dark:text-white!"
      width="16"
      height="16"
      name="whatsapp"
    />

    <CommonLabel class="text-neutral-950! dark:text-white!">
      {{ $t(articleTypeLabel) }}
    </CommonLabel>

    <template v-if="deliveryFailed">
      <CommonIcon width="16" height="16" name="warning" />
      <CommonLabel>{{ failureMessage || $t('Delivery failed') }}</CommonLabel>
    </template>

    <template v-else>
      <CommonIcon
        v-if="articleDeliveryStatus?.icon"
        width="16"
        height="16"
        :name="articleDeliveryStatus?.icon"
        :class="statusColorClass"
      />
      <CommonLabel :class="statusColorClass">{{ articleDeliveryStatus?.message }}</CommonLabel>
    </template>
  </div>
</template>
