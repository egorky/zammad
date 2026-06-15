// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import type { FormKitNode, FormKitPlugin } from '@formkit/core'

import {
  mountWhatsappTemplateComposer,
  setActiveWhatsappTemplateForm,
  unmountWhatsappTemplateComposer,
} from '#shared/composables/useWhatsappTemplateFormState.ts'
const WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'
const TICKET_CREATE_FORM_IDS = new Set(['ticket-create'])

const waitForNextFrame = () =>
  new Promise<void>((resolve) => {
    requestAnimationFrame(() => resolve())
  })

const waitForNode = async (formNode: FormKitNode, name: string, attempts = 60) => {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const node = formNode.find(name, 'name')

    if (node) return node

    await waitForNextFrame()
  }

  return null
}

const resolveFormKitFormId = (formNode: FormKitNode) => {
  const contextFormId =
    formNode.find('body', 'name')?.context?.formId ||
    formNode.find('group_id', 'name')?.context?.formId ||
    formNode.find('articleSenderType', 'name')?.context?.formId

  return (contextFormId || formNode.props.id) as string
}

const findComposerContainer = (formNode: FormKitNode, articleSenderType?: string) => {
  if (articleSenderType) {
    const tabPanel = document.getElementById(`tab-panel-${articleSenderType}`)

    if (tabPanel) return tabPanel as HTMLElement
  }

  const bodyNode = formNode.find('body', 'name')
  const bodyElement = bodyNode?.context?.id
    ? document.querySelector(`[data-id="${bodyNode.context.id}"]`)
    : null

  const tabPanelFromBody = bodyElement?.closest('[role="tabpanel"]') as HTMLElement | null
  if (tabPanelFromBody) return tabPanelFromBody

  const bodyParent = bodyElement?.parentElement
  if (bodyParent) return bodyParent

  const formKitFormId = resolveFormKitFormId(formNode)
  const formElement = document.querySelector(`[data-form-id="${formKitFormId}"]`)

  return (formElement?.closest('form')?.parentElement || formElement?.parentElement) as
    | HTMLElement
    | null
}

const waitForComposerContainer = async (formNode: FormKitNode, articleSenderType?: string) => {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const container = findComposerContainer(formNode, articleSenderType)

    if (container) return container

    await waitForNextFrame()
  }

  return findComposerContainer(formNode, articleSenderType)
}

const hideField = (formNode: FormKitNode, name: string, hidden = true) => {
  const field = formNode.find(name, 'name')
  field?.emit('prop:hidden', hidden)

  if (hidden) {
    field?.emit('prop:validation', 'optional')
  }
}

const hideTemplateFields = (formNode: FormKitNode, hidden = true) => {
  hideField(formNode, 'body', hidden)
  hideField(formNode, 'title', hidden)
  hideField(formNode, 'attachments', hidden)
}

const isTicketCreateForm = (formNode: FormKitNode) => {
  return TICKET_CREATE_FORM_IDS.has(formNode.props.id as string)
}

const updateTicketCreateComposer = async (formNode: FormKitNode) => {
  const articleSenderType = formNode.find('articleSenderType', 'name')?.value as string | undefined
  const groupId = formNode.find('group_id', 'name')?.value as number | string | undefined
  const formKitFormId = resolveFormKitFormId(formNode)

  if (articleSenderType !== WHATSAPP_TEMPLATE_CREATE_TYPE) {
    hideTemplateFields(formNode, false)
    unmountWhatsappTemplateComposer(formKitFormId)
    setActiveWhatsappTemplateForm(undefined)
    return
  }

  hideTemplateFields(formNode, true)
  setActiveWhatsappTemplateForm({ formId: formKitFormId })

  const container = await waitForComposerContainer(formNode, articleSenderType)
  if (!container) return

  await mountWhatsappTemplateComposer(formKitFormId, container, {
    groupId: groupId ? Number(groupId) : undefined,
  })
}

const whatsappOutboundTemplatesPlugin: FormKitPlugin = (node) => {
  if (node.name !== 'form') return

  node.on('created', () => {
    if (!isTicketCreateForm(node)) return

    const setup = async () => {
      const articleSenderTypeNode = await waitForNode(node, 'articleSenderType')
      if (!articleSenderTypeNode) return

      const refresh = () => {
        void updateTicketCreateComposer(node)
      }

      articleSenderTypeNode.on('commit', refresh)

      const groupIdNode = await waitForNode(node, 'group_id')
      groupIdNode?.on('commit', refresh)

      refresh()
    }

    void setup()
  })
}

export default whatsappOutboundTemplatesPlugin
