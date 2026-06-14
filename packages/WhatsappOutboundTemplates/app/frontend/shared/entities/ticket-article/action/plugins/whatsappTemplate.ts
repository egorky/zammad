// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

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
import type { FormRef } from '#shared/components/Form/types.ts'
import type {
  TicketArticleAction,
  TicketArticleType,
  TicketArticleActionPlugin,
} from '#shared/entities/ticket-article/action/plugins/types.ts'
import type { TicketById, TicketFormData, TicketUpdateFormData } from '#shared/entities/ticket/types.ts'
import type { FormSubmitData } from '#shared/components/Form/types.ts'

const ARTICLE_TYPE = 'whatsapp template message'

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

const mountComposer = (ticket: TicketById, form?: FormRef) => {
  if (!form?.formId) return

  setActiveWhatsappTemplateForm(form)

  const bodyNode = form.getNodeByName('body')
  const element = bodyNode?.context?.id
    ? document.querySelector(`[data-id="${bodyNode.context.id}"]`)?.parentElement
    : null

  const container = element || document.querySelector(`[data-form-id="${form.formId}"]`)

  if (!container) return

  hideBodyField(form, true)
  mountWhatsappTemplateComposer(form.formId, container as HTMLElement, {
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
      icon: 'file-text',
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
      icon: 'file-text',
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
        mountComposer(ticket, form)
      },
      onOpened(ticket, _context, form) {
        mountComposer(ticket, form)
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
