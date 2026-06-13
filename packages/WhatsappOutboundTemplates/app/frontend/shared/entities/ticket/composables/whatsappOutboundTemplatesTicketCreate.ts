// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { transformEditorHtml } from '#shared/components/Form/fields/FieldEditor/utils.ts'
import type { FormRef } from '#shared/components/Form/types.ts'
import {
  buildTemplatePreview,
  getActiveWhatsappTemplateFormId,
  getSelectedTemplate,
  getWhatsappTemplateFormState,
} from '#shared/composables/useWhatsappTemplateFormState.ts'
import type { TicketCreateInput } from '#shared/graphql/types.ts'

import type { TicketFormData } from '../types.ts'
import type { FormSubmitData } from '#shared/components/Form/types.ts'

const WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'

export const isWhatsappTemplateTicketCreate = (articleSenderType?: string) => {
  return articleSenderType === WHATSAPP_TEMPLATE_CREATE_TYPE
}

export const applyWhatsappTemplateToTicketCreateInput = (
  formData: FormSubmitData<TicketFormData>,
  input: TicketCreateInput,
  form?: FormRef,
) => {
  if (!isWhatsappTemplateTicketCreate(formData.articleSenderType as string)) return input

  const formId = getActiveWhatsappTemplateFormId() || form?.formId
  if (!formId) return input

  const state = getWhatsappTemplateFormState(formId)
  const template = getSelectedTemplate(state)

  if (!template) return input

  const preview = buildTemplatePreview(template, state)
  const componentsJson = buildComponentsJson(state.variableValues)

  if (!input.article) return input

  input.article.type = 'whatsapp template message'
  input.article.contentType = 'text/plain'
  input.article.body = transformEditorHtml(preview)
  input.article.preferences = {
    whatsapp_template: {
      template_id: template.id,
      name: template.name,
      language: template.language,
      variable_values: state.variableValues,
      components_json: componentsJson,
      channel_id: template.channel_id,
    },
  }

  return input
}

const buildComponentsJson = (
  variableValues: ReturnType<typeof getWhatsappTemplateFormState>['variableValues'],
) => {
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
