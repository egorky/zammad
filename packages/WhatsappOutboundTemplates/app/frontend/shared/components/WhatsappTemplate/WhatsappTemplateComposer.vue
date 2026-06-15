<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'

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
import { useAppName } from '#shared/composables/useAppName.ts'
import { i18n } from '#shared/i18n.ts'

const props = defineProps<{
  formId: string
  channelId?: number
  groupId?: number
}>()

const state = getWhatsappTemplateFormState(props.formId)
const isMobile = computed(() => useAppName() === 'mobile')
const showTemplatePicker = ref(false)
const showLanguagePicker = ref(false)

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
    showTemplatePicker.value = false
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
    showLanguagePicker.value = false
  },
})

const selectedTemplate = computed(() => getSelectedTemplate(state))

const preview = computed(() => buildTemplatePreview(selectedTemplate.value, state))

const containerClass = computed(() => {
  if (isMobile.value) {
    return 'border-gray-900 bg-gray-600 text-white'
  }

  return 'border-neutral-300 bg-neutral-50 dark:border-gray-900 dark:bg-gray-500'
})

const fieldClass = computed(() => {
  if (isMobile.value) {
    return 'rounded border border-gray-900 bg-gray-500 px-3 py-3 text-base text-white'
  }

  return 'rounded border border-neutral-300 bg-white px-3 py-2 text-sm dark:border-gray-900 dark:bg-gray-500 dark:text-white'
})

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

const selectTemplateOption = (value: string) => {
  selectedTemplateName.value = value
}

const selectLanguageOption = (value: string) => {
  selectedLanguage.value = value
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
  <div class="col-span-full mb-3 flex flex-col gap-3 rounded-lg border p-3" :class="containerClass">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="text-sm font-semibold" :class="isMobile ? 'text-white' : 'text-gray-500 dark:text-white'">
        {{ i18n.t('WhatsApp Template') }}
      </div>
      <button
        class="rounded px-3 py-1.5 text-sm font-semibold text-blue-800 hover:bg-blue-200 disabled:opacity-50 dark:text-blue-800"
        type="button"
        :disabled="state.syncing || (!channelId && !groupId)"
        @click="handleSync"
      >
        {{
          state.syncing ? i18n.t('Syncing…') : i18n.t('Sync templates')
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
      class="text-sm"
      :class="isMobile ? 'text-white' : 'text-gray-100 dark:text-neutral-400'"
    >
      {{ i18n.t('Loading templates…') }}
    </div>

    <template v-else>
      <div class="grid gap-3 md:grid-cols-2">
        <label class="relative flex flex-col gap-1 text-sm">
          <span class="font-medium" :class="isMobile ? 'text-white' : 'text-gray-500 dark:text-white'">{{ i18n.t('Template') }}</span>
          <template v-if="isMobile">
            <button
              type="button"
              class="w-full text-left"
              :class="fieldClass"
              @click="showTemplatePicker = !showTemplatePicker"
            >
              {{ selectedTemplateName || i18n.t('Select a template') }}
            </button>
            <div
              v-if="showTemplatePicker"
              class="absolute top-full z-50 mt-1 max-h-48 w-full overflow-y-auto rounded border border-gray-900 bg-gray-500 shadow-lg"
            >
              <button
                v-for="option in templateOptions"
                :key="option.value"
                type="button"
                class="block w-full px-3 py-3 text-left text-base text-white hover:bg-gray-400"
                @click="selectTemplateOption(option.value)"
              >
                {{ option.label }}
              </button>
            </div>
          </template>
          <select
            v-else
            v-model="selectedTemplateName"
            :class="fieldClass"
          >
            <option value="">
              {{ i18n.t('Select a template') }}
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

        <label class="relative flex flex-col gap-1 text-sm">
          <span class="font-medium" :class="isMobile ? 'text-white' : 'text-gray-500 dark:text-white'">{{ i18n.t('Language') }}</span>
          <template v-if="isMobile">
            <button
              type="button"
              class="w-full text-left"
              :class="fieldClass"
              :disabled="!selectedTemplateName"
              @click="showLanguagePicker = !showLanguagePicker"
            >
              {{ selectedLanguage || i18n.t('Select a language') }}
            </button>
            <div
              v-if="showLanguagePicker"
              class="absolute top-full z-50 mt-1 max-h-48 w-full overflow-y-auto rounded border border-gray-900 bg-gray-500 shadow-lg"
            >
              <button
                v-for="option in languageOptions"
                :key="option.value"
                type="button"
                class="block w-full px-3 py-3 text-left text-base text-white hover:bg-gray-400"
                @click="selectLanguageOption(option.value)"
              >
                {{ option.label }}
              </button>
            </div>
          </template>
          <select
            v-else
            v-model="selectedLanguage"
            :class="fieldClass"
            :disabled="!selectedTemplateName"
          >
            <option value="">
              {{ i18n.t('Select a language') }}
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
        <div class="text-sm font-medium" :class="isMobile ? 'text-white' : 'text-gray-500 dark:text-white'">
          {{ i18n.t('Header variables') }}
        </div>
        <label
          v-for="(variable, index) in selectedTemplate.variables.header"
          :key="`header-${variable.position}`"
          class="flex flex-col gap-1 text-sm"
        >
          <span>{{ variable.label }}</span>
          <input
            v-model="state.variableValues.header[index]"
            :class="fieldClass"
            type="text"
          />
        </label>
      </div>

      <div
        v-if="selectedTemplate?.variables?.body?.length"
        class="flex flex-col gap-2"
      >
        <div class="text-sm font-medium" :class="isMobile ? 'text-white' : 'text-gray-500 dark:text-white'">
          {{ i18n.t('Body variables') }}
        </div>
        <label
          v-for="(variable, index) in selectedTemplate.variables.body"
          :key="`body-${variable.position}`"
          class="flex flex-col gap-1 text-sm"
        >
          <span>{{ variable.label }}</span>
          <input
            v-model="state.variableValues.body[index]"
            :class="fieldClass"
            type="text"
          />
        </label>
      </div>

      <div
        v-if="preview"
        class="rounded border border-dashed px-3 py-2 text-sm"
        :class="isMobile ? 'border-gray-900 text-white' : 'border-neutral-300 text-gray-500 dark:border-gray-900 dark:text-white'"
      >
        <div class="mb-1 font-medium">{{ i18n.t('Preview') }}</div>
        <div>{{ preview }}</div>
      </div>
    </template>
  </div>
</template>
