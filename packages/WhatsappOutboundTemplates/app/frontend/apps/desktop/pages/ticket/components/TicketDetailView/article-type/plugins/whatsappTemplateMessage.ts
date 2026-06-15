// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { useWhatsappArticleDelivery } from '#shared/composables/useWhatsappArticleDelivery.ts'

import type { ChannelModule } from '#desktop/pages/ticket/components/TicketDetailView/article-type/types.ts'
import ArticleMetaWhatsappDeliveryStatus from '#desktop/pages/ticket/components/TicketDetailView/ArticleMeta/ArticleMetaWhatsappDeliveryStatus.vue'

export default <ChannelModule>{
  name: 'whatsapp template message',
  label: __('WhatsApp template'),
  metaLabel: __('whatsapp template message'),
  icon: 'whatsapp',
  additionalFields: [
    {
      name: 'preferences.whatsapp',
      label: __('Message status'),
      show: (article) => {
        const { hasDeliveryStatus, deliveryFailed } = useWhatsappArticleDelivery(article)

        return hasDeliveryStatus.value || deliveryFailed.value
      },
      order: 400,
      component: ArticleMetaWhatsappDeliveryStatus,
    },
  ],
}
