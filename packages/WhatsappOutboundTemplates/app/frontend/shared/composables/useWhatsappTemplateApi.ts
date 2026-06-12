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

export const fetchWhatsappTemplates = (channelId: number, status = 'APPROVED') => {
  const params = new URLSearchParams({
    channel_id: channelId.toString(),
  })

  if (status) params.set('status', status)

  return request<WhatsappMessageTemplate[]>(`/whatsapp_message_templates?${params.toString()}`)
}

export const syncWhatsappTemplates = (channelId: number) => {
  return request<{ message: string; templates: WhatsappMessageTemplate[] }>(
    '/whatsapp_message_templates/sync',
    {
      method: 'POST',
      body: JSON.stringify({ channel_id: channelId }),
    },
  )
}
