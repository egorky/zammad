// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { useWhatsapp } from '#shared/entities/ticket/channel/composables/useWhatsapp.ts'

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
        const { hasDeliveryStatus } = useWhatsapp(article)
        const failed =
          article.value.preferences?.delivery_status === 'fail' ||
          article.value.preferences?.whatsapp?.delivery_status === 'fail'

        return (
          hasDeliveryStatus.value ||
          failed ||
          Boolean(article.value.preferences?.whatsapp?.message_id)
        )
      },
      order: 400,
      component: ArticleMetaWhatsappDeliveryStatus,
    },
  ],
}
