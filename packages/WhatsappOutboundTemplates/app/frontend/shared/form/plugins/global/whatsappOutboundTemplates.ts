// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import type { FormKitNode, FormKitPlugin } from '@formkit/core'

import {
  mountWhatsappTemplateComposer,
  setActiveWhatsappTemplateForm,
  unmountWhatsappTemplateComposer,
} from '#shared/composables/useWhatsappTemplateFormState.ts'

const WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'

const findComposerContainer = (formNode: FormKitNode) => {
  const bodyNode = formNode.find('body', 'name')
  const element = bodyNode?.context?.id
    ? document.querySelector(`[data-id="${bodyNode.context.id}"]`)?.parentElement
    : null

  return (element || document.querySelector(`[data-form-id="${formNode.props.id}"]`)) as
    | HTMLElement
    | null
}

const hideBodyField = (formNode: FormKitNode, hidden = true) => {
  const body = formNode.find('body', 'name')
  body?.emit('prop:hidden', hidden)
}

const updateTicketCreateComposer = (formNode: FormKitNode) => {
  const articleSenderType = formNode.find('articleSenderType', 'name')?.value as string | undefined
  const groupId = formNode.find('group_id', 'name')?.value as number | string | undefined

  if (articleSenderType !== WHATSAPP_TEMPLATE_CREATE_TYPE) {
    hideBodyField(formNode, false)
    unmountWhatsappTemplateComposer(formNode.props.id as string)
    setActiveWhatsappTemplateForm(undefined)
    return
  }

  const container = findComposerContainer(formNode)
  if (!container || !groupId) return

  hideBodyField(formNode, true)
  setActiveWhatsappTemplateForm({ formId: formNode.props.id as string })

  mountWhatsappTemplateComposer(formNode.props.id as string, container, {
    groupId: Number(groupId),
  })
}

const whatsappOutboundTemplatesPlugin: FormKitPlugin = (node) => {
  if (node.name !== 'form') return

  node.on('created', () => {
    const articleSenderTypeNode = node.find('articleSenderType', 'name')
    if (!articleSenderTypeNode) return

    const refresh = () => updateTicketCreateComposer(node)

    articleSenderTypeNode.on('commit', refresh)
    node.find('group_id', 'name')?.on('commit', refresh)

    refresh()
  })
}

export default whatsappOutboundTemplatesPlugin
