// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { nextTick } from 'vue'

import { EnumChannelArea } from '#shared/graphql/types.ts'
import {
  buildTemplatePreview,
  getActiveWhatsappTemplateForm,
  getActiveWhatsappTemplateFormId,
  getSelectedTemplate,
  getWhatsappTemplateFormState,
  mountWhatsappTemplateComposer,
  setActiveWhatsappTemplateForm,
  unmountWhatsappTemplateComposer,
} from '#shared/composables/useWhatsappTemplateFormState.ts'
import { useAppName } from '#shared/composables/useAppName.ts'
import type { FormRef } from '#shared/components/Form/types.ts'
import type {
  TicketArticleAction,
  TicketArticleType,
  TicketArticleActionPlugin,
} from '#shared/entities/ticket-article/action/plugins/types.ts'
import type { TicketById, TicketFormData, TicketUpdateFormData } from '#shared/entities/ticket/types.ts'
import type { FormSubmitData } from '#shared/components/Form/types.ts'

const ARTICLE_TYPE = 'whatsapp template message'
const TEMPLATE_ACTION_ICON = 'snippet'

const isWhatsappTicket = (ticket: TicketById) => {
  return (
    ticket.initialChannel === EnumChannelArea.WhatsAppBusiness &&
    Boolean(ticket.preferences?.whatsapp?.from?.phone_number)
  )
}

const getChannelId = (ticket: TicketById) => {
  const channelId = ticket.preferences?.channel_id

  return typeof channelId === 'number' ? channelId : Number(channelId)
}

const hideBodyField = (form?: FormRef, hidden = true) => {
  const body = form?.getNodeByName('body')
  body?.emit('prop:hidden', hidden)
}

const waitForMobileReplyForm = async () => {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const replyForm = document.querySelector('[data-ticket-article-reply-form]')

    if (replyForm?.children.length) return

    await new Promise<void>((resolve) => {
      requestAnimationFrame(() => resolve())
    })
  }
}

const resolveComposerContainer = (form: FormRef) => {
  if (useAppName() === 'mobile') {
    const replyForm = document.querySelector('[data-ticket-article-reply-form]')
    if (replyForm) return replyForm as HTMLElement
  }

  const bodyNode = form.getNodeByName('body')
  const element = bodyNode?.context?.id
    ? document.querySelector(`[data-id="${bodyNode.context.id}"]`)?.parentElement
    : null

  return (element || document.querySelector(`[data-form-id="${form.formId}"]`)) as HTMLElement | null
}

const mountComposer = async (ticket: TicketById, form?: FormRef) => {
  if (!form?.formId) return

  setActiveWhatsappTemplateForm(form)

  if (useAppName() === 'mobile') {
    await nextTick()
    await waitForMobileReplyForm()
  }

  const container = resolveComposerContainer(form)
  if (!container) return

  hideBodyField(form, true)
  await mountWhatsappTemplateComposer(form.formId, container, {
    channelId: getChannelId(ticket),
  })
}

const unmountComposer = (form?: FormRef | { formId?: string }) => {
  if (!form?.formId) return

  if ('getNodeByName' in form) {
    hideBodyField(form, false)
  }

  unmountWhatsappTemplateComposer(form.formId)
  setActiveWhatsappTemplateForm(undefined)
}

const actionPlugin: TicketArticleActionPlugin = {
  order: 310,

  addActions(ticket) {
    if (!isWhatsappTicket(ticket)) return []

    const action: TicketArticleAction = {
      apps: ['mobile', 'desktop'],
      label: __('Send template'),
      name: ARTICLE_TYPE,
      icon: TEMPLATE_ACTION_ICON,
      alwaysVisible: true,
      view: {
        agent: ['change'],
      },
      perform(_ticket, _article, { openReplyForm }) {
        openReplyForm({ articleType: ARTICLE_TYPE })
      },
    }

    return [action]
  },

  addTypes(ticket) {
    if (!isWhatsappTicket(ticket)) return []

    const type: TicketArticleType = {
      apps: ['mobile', 'desktop'],
      value: ARTICLE_TYPE,
      label: __('WhatsApp Template'),
      buttonLabel: __('Send template'),
      icon: TEMPLATE_ACTION_ICON,
      view: {
        agent: ['change'],
      },
      internal: false,
      contentType: 'text/plain',
      fields: {
        body: {
          required: false,
        },
      },
      onSelected(ticket, _context, form) {
        void mountComposer(ticket, form)
      },
      onOpened(ticket, _context, form) {
        void mountComposer(ticket, form)
      },
      onDeselected() {
        unmountComposer(getActiveWhatsappTemplateForm())
      },
      updateForm(formValues: FormSubmitData<TicketFormData | TicketUpdateFormData>) {
        const formId = getActiveWhatsappTemplateFormId()
        if (!formId) return formValues

        const state = getWhatsappTemplateFormState(formId)
        const template = getSelectedTemplate(state)

        if (!template) return formValues

        const preview = buildTemplatePreview(template, state)
        const componentsJson = buildComponentsJson(template, state.variableValues)

        return {
          ...formValues,
          article: {
            ...formValues.article,
            body: preview,
            preferences: {
              whatsapp_template: {
                template_id: template.id,
                name: template.name,
                language: template.language,
                variable_values: state.variableValues,
                components_json: componentsJson,
              },
            },
          },
        }
      },
    }

    return [type]
  },
}

const buildComponentsJson = (
  template: ReturnType<typeof getSelectedTemplate>,
  variableValues: ReturnType<typeof getWhatsappTemplateFormState>['variableValues'],
) => {
  if (!template) return []

  const components: Record<string, unknown>[] = []

  if (variableValues.body.some(Boolean)) {
    components.push({
      type: 'body',
      parameters: variableValues.body.filter(Boolean).map((text) => ({ type: 'text', text })),
    })
  }

  if (variableValues.header.some(Boolean)) {
    components.push({
      type: 'header',
      parameters: variableValues.header.filter(Boolean).map((text) => ({ type: 'text', text })),
    })
  }

  variableValues.buttons.forEach((buttonValues, index) => {
    if (!buttonValues.some(Boolean)) return

    components.push({
      type: 'button',
      sub_type: 'url',
      index: index.toString(),
      parameters: buttonValues.filter(Boolean).map((text) => ({ type: 'text', text })),
    })
  })

  return components
}

export default actionPlugin
