<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, toRef } from 'vue'

import { useWhatsapp } from '#shared/entities/ticket/channel/composables/useWhatsapp.ts'
import type { TicketArticle } from '#shared/entities/ticket/types.ts'

interface Props {
  context: {
    article: TicketArticle
  }
}

const props = defineProps<Props>()

const { articleDeliveryStatus } = useWhatsapp(toRef(props.context, 'article'))

const deliveryFailed = computed(() => {
  const preferences = props.context.article.preferences

  return (
    preferences?.delivery_status === 'fail' || preferences?.whatsapp?.delivery_status === 'fail'
  )
})

const failureMessage = computed(() => {
  const preferences = props.context.article.preferences

  return preferences?.delivery_status_message || preferences?.whatsapp?.delivery_status_message
})

const articleTypeLabel = computed(() => {
  if (props.context.article.type?.name === 'whatsapp template message') {
    return __('whatsapp template message')
  }

  return __('whatsapp message')
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
      />
      <CommonLabel>{{ articleDeliveryStatus?.message }}</CommonLabel>
    </template>
  </div>
</template>
