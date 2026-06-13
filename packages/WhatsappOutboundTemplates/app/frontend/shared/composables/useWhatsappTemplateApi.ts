// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { getCSRFToken } from '#shared/server/apollo/utils/csrfToken.ts'
import { useApplicationStore } from '#shared/stores/application.ts'

export interface WhatsappTemplateVariableDefinition {
  position: number
  label: string
}

export interface WhatsappTemplateVariables {
  body?: WhatsappTemplateVariableDefinition[]
  header?: WhatsappTemplateVariableDefinition[]
  buttons?: WhatsappTemplateVariableDefinition[][]
}

export interface WhatsappMessageTemplate {
  id: number
  channel_id: number
  name: string
  language: string
  status?: string
  category?: string
  meta_template_id?: string
  components?: Record<string, unknown>[]
  variables?: WhatsappTemplateVariables
  updated_at?: string
  created_at?: string
}

const request = async <T>(path: string, options: RequestInit = {}): Promise<T> => {
  const application = useApplicationStore()
  const apiPath = application.config.api_path || '/api/v1'
  const url = `${apiPath}${path}`

  const response = await fetch(url, {
    credentials: 'same-origin',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': getCSRFToken() || '',
      ...(options.headers || {}),
    },
    ...options,
  })

  if (!response.ok) {
    const errorBody = await response.json().catch(() => ({}))
    const message =
      (errorBody as { error_human?: string; error?: string }).error_human ||
      (errorBody as { error?: string }).error ||
      response.statusText

    throw new Error(message)
  }

  return response.json() as Promise<T>
}

type WhatsappTemplateScope = {
  channelId?: number
  groupId?: number
}

const buildScopeParams = (scope: WhatsappTemplateScope) => {
  const params = new URLSearchParams()

  if (scope.channelId) params.set('channel_id', scope.channelId.toString())
  if (scope.groupId) params.set('group_id', scope.groupId.toString())

  return params
}

export const fetchWhatsappTemplates = (
  scope: WhatsappTemplateScope,
  status = 'APPROVED',
) => {
  const params = buildScopeParams(scope)

  if (status) params.set('status', status)

  return request<WhatsappMessageTemplate[]>(`/whatsapp_message_templates?${params.toString()}`)
}

export const syncWhatsappTemplates = (scope: WhatsappTemplateScope) => {
  return request<{ message: string; templates: WhatsappMessageTemplate[] }>(
    '/whatsapp_message_templates/sync',
    {
      method: 'POST',
      body: JSON.stringify(
        scope.channelId
          ? { channel_id: scope.channelId }
          : { group_id: scope.groupId },
      ),
    },
  )
}
