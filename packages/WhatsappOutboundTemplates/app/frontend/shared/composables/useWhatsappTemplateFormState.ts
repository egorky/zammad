// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { reactive, type App, createApp, type ComponentPublicInstance } from 'vue'

import type { FormRef } from '#shared/components/Form/types.ts'

import type { WhatsappMessageTemplate } from './useWhatsappTemplateApi.ts'

export interface WhatsappTemplateFormState {
  channelId?: number
  templates: WhatsappMessageTemplate[]
  selectedTemplateId?: number
  selectedLanguage?: string
  variableValues: {
    body: string[]
    header: string[]
    buttons: string[][]
  }
  loading: boolean
  syncing: boolean
  error?: string
}

const states = new Map<string, WhatsappTemplateFormState>()
const mountedApps = new Map<string, { app: App; instance: ComponentPublicInstance }>()
let activeForm: FormRef | undefined

export const setActiveWhatsappTemplateForm = (form?: FormRef) => {
  activeForm = form
}

export const getActiveWhatsappTemplateForm = () => activeForm

export const getActiveWhatsappTemplateFormId = () => activeForm?.formId

export const getWhatsappTemplateFormState = (formId: string) => {
  if (!states.has(formId)) {
    states.set(
      formId,
      reactive({
        templates: [],
        variableValues: {
          body: [],
          header: [],
          buttons: [],
        },
        loading: false,
        syncing: false,
      }),
    )
  }

  return states.get(formId)!
}

export const clearWhatsappTemplateFormState = (formId: string) => {
  states.delete(formId)
  unmountWhatsappTemplateComposer(formId)
}

export const getSelectedTemplate = (state: WhatsappTemplateFormState) => {
  if (!state.selectedTemplateId) return undefined

  return state.templates.find((template) => template.id === state.selectedTemplateId)
}

export const buildTemplatePreview = (template?: WhatsappMessageTemplate, state?: WhatsappTemplateFormState) => {
  if (!template || !state) return ''

  const bodyComponent = template.components?.find(
    (component) => (component.type as string)?.toUpperCase() === 'BODY',
  )

  if (!bodyComponent?.text) return template.name

  let text = String(bodyComponent.text)

  state.variableValues.body.forEach((value, index) => {
    text = text.replace(`{{${index + 1}}}`, value || `{{${index + 1}}}`)
  })

  return text
}

export const mountWhatsappTemplateComposer = async (
  formId: string,
  container: HTMLElement,
  channelId?: number,
) => {
  unmountWhatsappTemplateComposer(formId)

  const { default: WhatsappTemplateComposer } = await import(
    '../components/WhatsappTemplate/WhatsappTemplateComposer.vue'
  )

  const mountPoint = document.createElement('div')
  mountPoint.setAttribute('data-whatsapp-template-composer', formId)
  container.prepend(mountPoint)

  const state = getWhatsappTemplateFormState(formId)
  state.channelId = channelId

  const app = createApp(WhatsappTemplateComposer, { formId, channelId })
  const instance = app.mount(mountPoint)

  mountedApps.set(formId, { app, instance })
}

export const unmountWhatsappTemplateComposer = (formId: string) => {
  const mounted = mountedApps.get(formId)

  if (mounted) {
    mounted.app.unmount()
    mountedApps.delete(formId)
  }

  document.querySelector(`[data-whatsapp-template-composer="${formId}"]`)?.remove()
}
