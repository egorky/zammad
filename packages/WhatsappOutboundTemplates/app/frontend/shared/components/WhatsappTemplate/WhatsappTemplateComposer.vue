<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'

import {
  fetchWhatsappTemplates,
  syncWhatsappTemplates,
  type WhatsappMessageTemplate,
} from '#shared/composables/useWhatsappTemplateApi.ts'
import {
  buildTemplatePreview,
  getSelectedTemplate,
  getWhatsappTemplateFormState,
} from '#shared/composables/useWhatsappTemplateFormState.ts'
import { i18n } from '#shared/i18n.ts'

const props = defineProps<{
  formId: string
  channelId?: number
  groupId?: number
}>()

const state = getWhatsappTemplateFormState(props.formId)

const templateOptions = computed(() => {
  const names = [...new Set(state.templates.map((template) => template.name))]

  return names.map((name) => ({
    value: name,
    label: name,
  }))
})

const languageOptions = computed(() => {
  if (!state.selectedTemplateId) {
    const selectedByName = state.templates.filter(
      (template) => template.name === selectedTemplateName.value,
    )
    return selectedByName.map((template) => ({
      value: template.language,
      label: template.language,
    }))
  }

  const selected = getSelectedTemplate(state)
  if (!selected) return []

  return state.templates
    .filter((template) => template.name === selected.name)
    .map((template) => ({
      value: template.language,
      label: template.language,
    }))
})

const selectedTemplateName = computed({
  get: () => getSelectedTemplate(state)?.name || '',
  set: (name: string) => {
    const template = state.templates.find((item) => item.name === name)
    state.selectedTemplateId = template?.id
    state.selectedLanguage = template?.language
    resetVariableValues(template)
  },
})

const selectedLanguage = computed({
  get: () => state.selectedLanguage || getSelectedTemplate(state)?.language || '',
  set: (language: string) => {
    state.selectedLanguage = language
    const template = state.templates.find(
      (item) => item.name === selectedTemplateName.value && item.language === language,
    )
    state.selectedTemplateId = template?.id
    resetVariableValues(template)
  },
})

const selectedTemplate = computed(() => getSelectedTemplate(state))

const preview = computed(() => buildTemplatePreview(selectedTemplate.value, state))

const loadTemplates = async () => {
  if (!props.channelId && !props.groupId) {
    state.error = i18n.t('Select a group with an active WhatsApp channel first.')
    return
  }

  state.loading = true
  state.error = undefined

  try {
    state.templates = await fetchWhatsappTemplates({
      channelId: props.channelId,
      groupId: props.groupId,
    })
  } catch (error) {
    state.error = error instanceof Error ? error.message : i18n.t('Unable to load templates.')
  } finally {
    state.loading = false
  }
}

const handleSync = async () => {
  if (!props.channelId && !props.groupId) return

  state.syncing = true
  state.error = undefined

  try {
    const result = await syncWhatsappTemplates({
      channelId: props.channelId,
      groupId: props.groupId,
    })
    state.templates = result.templates
  } catch (error) {
    state.error = error instanceof Error ? error.message : i18n.t('Unable to sync templates.')
  } finally {
    state.syncing = false
  }
}

const resetVariableValues = (template?: WhatsappMessageTemplate) => {
  state.variableValues = {
    body: Array(template?.variables?.body?.length || 0).fill(''),
    header: Array(template?.variables?.header?.length || 0).fill(''),
    buttons: (template?.variables?.buttons || []).map((buttonVariables) =>
      Array(buttonVariables?.length || 0).fill(''),
    ),
  }
}

onMounted(() => {
  loadTemplates()
})

watch(
  () => [props.channelId, props.groupId],
  () => {
    loadTemplates()
  },
)
</script>

<template>
  <div class="col-span-full mb-3 flex flex-col gap-3 rounded-lg border border-neutral-300 bg-neutral-50 p-3 dark:border-gray-900 dark:bg-gray-500">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="text-sm font-semibold text-gray-500 dark:text-white">
        {{ $t('WhatsApp Template') }}
      </div>
      <button
        class="rounded px-3 py-1.5 text-sm font-semibold text-blue-800 hover:bg-blue-200 disabled:opacity-50 dark:text-blue-800"
        type="button"
        :disabled="state.syncing || (!channelId && !groupId)"
        @click="handleSync"
      >
        {{
          state.syncing ? $t('Syncing…') : $t('Sync templates')
        }}
      </button>
    </div>

    <div
      v-if="state.error"
      class="rounded bg-red-200 px-3 py-2 text-sm text-red-500 dark:bg-red-500 dark:text-white"
      role="alert"
    >
      {{ state.error }}
    </div>

    <div
      v-if="state.loading"
      class="text-sm text-gray-100 dark:text-neutral-400"
    >
      {{ $t('Loading templates…') }}
    </div>

    <template v-else>
      <div class="grid gap-3 md:grid-cols-2">
        <label class="flex flex-col gap-1 text-sm">
          <span class="font-medium text-gray-500 dark:text-white">{{ $t('Template') }}</span>
          <select
            v-model="selectedTemplateName"
            class="rounded border border-neutral-300 bg-white px-3 py-2 text-sm dark:border-gray-900 dark:bg-gray-500 dark:text-white"
          >
            <option value="">
              {{ $t('Select a template') }}
            </option>
            <option
              v-for="option in templateOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-sm">
          <span class="font-medium text-gray-500 dark:text-white">{{ $t('Language') }}</span>
          <select
            v-model="selectedLanguage"
            class="rounded border border-neutral-300 bg-white px-3 py-2 text-sm dark:border-gray-900 dark:bg-gray-900 dark:text-white"
            :disabled="!selectedTemplateName"
          >
            <option value="">
              {{ $t('Select a language') }}
            </option>
            <option
              v-for="option in languageOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
      </div>

      <div
        v-if="selectedTemplate?.variables?.header?.length"
        class="flex flex-col gap-2"
      >
        <div class="text-sm font-medium text-gray-500 dark:text-white">
          {{ $t('Header variables') }}
        </div>
        <label
          v-for="(variable, index) in selectedTemplate.variables.header"
          :key="`header-${variable.position}`"
          class="flex flex-col gap-1 text-sm"
        >
          <span>{{ variable.label }}</span>
          <input
            v-model="state.variableValues.header[index]"
            class="rounded border border-neutral-300 bg-white px-3 py-2 text-sm dark:border-gray-900 dark:bg-gray-500 dark:text-white"
            type="text"
          />
        </label>
      </div>

      <div
        v-if="selectedTemplate?.variables?.body?.length"
        class="flex flex-col gap-2"
      >
        <div class="text-sm font-medium text-gray-500 dark:text-white">
          {{ $t('Body variables') }}
        </div>
        <label
          v-for="(variable, index) in selectedTemplate.variables.body"
          :key="`body-${variable.position}`"
          class="flex flex-col gap-1 text-sm"
        >
          <span>{{ variable.label }}</span>
          <input
            v-model="state.variableValues.body[index]"
            class="rounded border border-neutral-300 bg-white px-3 py-2 text-sm dark:border-gray-900 dark:bg-gray-900 dark:text-white"
            type="text"
          />
        </label>
      </div>

      <div
        v-if="preview"
        class="rounded border border-dashed border-neutral-300 px-3 py-2 text-sm text-gray-500 dark:border-gray-900 dark:text-white"
      >
        <div class="mb-1 font-medium">{{ $t('Preview') }}</div>
        <div>{{ preview }}</div>
      </div>
    </template>
  </div>
</template>
