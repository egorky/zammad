# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'
WHATSAPP_TEMPLATE_ARTICLE_TYPE = 'whatsapp template message'

whatsappTemplateApiPath = ->
  App.Config.get('api_path') || '/api/v1'

whatsappTemplateComponentType = (component) ->
  type = component?.type || component?['type']
  "#{type}".toUpperCase()

whatsappTemplateComponentText = (component) ->
  component?.text || component?['text'] || ''

whatsappReplaceTemplateVariables = (text, values) ->
  return '' if !text

  result = "#{text}"
  for value, index in values || []
    replacement = if _.isEmpty(value) then "{{#{index + 1}}}" else value
    result = result.replace("{{#{index + 1}}}", replacement)
  result

buildWhatsappTemplatePreviewText = (template, variableValues = {}) ->
  return '' if !template

  variableValues ||= {}
  parts = []

  for component in template.components || []
    type = whatsappTemplateComponentType(component)
    text = whatsappTemplateComponentText(component)

    if type is 'HEADER' && text
      parts.push(whatsappReplaceTemplateVariables(text, variableValues.header))
    else if type is 'BODY' && text
      parts.push(whatsappReplaceTemplateVariables(text, variableValues.body))
    else if type is 'FOOTER' && text
      parts.push(text)

  parts.join('\n\n') || template.name

formatWhatsappTemplateVariablesSummary = (variables) ->
  variables ||= {}
  lines = []

  appendSection = (label, items) ->
    return if _.isEmpty(items)
    lines.push("#{label}:")
    for item in items
      position = item.position || '-'
      itemLabel = item.label || "Variable #{position}"
      lines.push("  • #{itemLabel}")

  appendSection(__('Header variables'), variables.header)
  appendSection(__('Body variables'), variables.body)

  if !_.isEmpty(variables.buttons)
    for buttonVariables, buttonIndex in variables.buttons
      appendSection("#{__('Button variables')} #{buttonIndex + 1}", buttonVariables)

  lines.join('\n')

showWhatsappTemplateSyncResultModal = (data, $container) ->
  templates = data?.templates || []
  count = data?.count ? templates.length

  if !count
    message = data?.message || __('No templates were found in your Meta account.')
  else
    lines = templates.map (template) ->
      status = template.status || '-'
      "• #{template.name} (#{template.language}) — #{status}"

    headline = data?.message || App.i18n.translateInline(__('%{count} templates synchronized:', count))
    message = "#{headline}\n\n#{lines.join('\n')}"

  container = $container || $('.content').first()
  container = $('body') if !container.length

  new App.ControllerConfirm(
    head: __('WhatsApp Templates')
    message: message
    buttonSubmit: __('OK')
    buttonCancel: false
    buttonClass: 'btn--primary'
    callback: =>
    container: container
  )

# Global sync handler: works even when ChannelWhatsapp controller events are not bound.
$(document).off('click.whatsappTemplateSync').on 'click.whatsappTemplateSync', '.js-sync-whatsapp-templates', (e) ->
  e.preventDefault()
  e.stopPropagation()

  $button = $(e.currentTarget)
  channelId = $button.attr('data-id')
  return if !channelId
  return if $button.hasClass('is-loading')

  $button.addClass('is-loading is-active')

  App.Ajax.request(
    id: 'whatsapp_templates_sync'
    type: 'POST'
    url: "#{whatsappTemplateApiPath()}/whatsapp_message_templates/sync"
    data: JSON.stringify({ channel_id: channelId })
    success: (data) =>
      $button.removeClass('is-loading is-active')
      App.Event.trigger 'notify',
        type: 'success'
        msg:  App.i18n.translateContent(data.message || __('WhatsApp templates synchronized successfully.'))
      showWhatsappTemplateSyncResultModal(data, $button.closest('.content'))
    error: (xhr) =>
      $button.removeClass('is-loading is-active')
      response = {}
      try
        response = JSON.parse(xhr.responseText)
      catch error
        response = {}

      message = response.error_human || response.error || __('Unable to sync WhatsApp templates.')
      App.Event.trigger 'notify',
        type: 'error'
        msg:  App.i18n.translateContent(message)
  )

# Fallback when ChannelWhatsapp controller events are not bound.
$(document).off('click.whatsappTemplateView').on 'click.whatsappTemplateView', '.js-view-whatsapp-templates', (e) ->
  e.preventDefault()
  e.stopPropagation()

  $button = $(e.currentTarget)
  channelId = $button.attr('data-id')
  return if !channelId

  controller = $button.closest('.content').find('[data-whatsapp-channel-controller]').data('whatsappChannelController')

  if controller?.loadWhatsappTemplates
    controller.loadWhatsappTemplates(channelId, $button)
    return

  return if $button.hasClass('is-loading')
  $button.addClass('is-loading is-active')

  App.Ajax.request(
    id: 'whatsapp_templates_view_fallback'
    type: 'GET'
    url: "#{whatsappTemplateApiPath()}/whatsapp_message_templates?channel_id=#{channelId}"
    success: (data) =>
      $button.removeClass('is-loading is-active')
      $content = $button.closest('.content')
      channel = App.Channel.find(channelId)
      helpers =
        statusClass: (status) ->
          normalized = "#{status}".toUpperCase()
          switch normalized
            when 'APPROVED' then 'success'
            when 'PENDING', 'IN_APPEAL' then 'warning'
            when 'REJECTED', 'PAUSED', 'DISABLED' then 'danger'
            else 'muted'
        preview: (template) ->
          parts = []
          for component in template?.components || []
            type = whatsappTemplateComponentType(component)
            text = whatsappTemplateComponentText(component)
            format = component?.format || component?['format']
            buttons = component?.buttons || component?['buttons']
            if type is 'HEADER'
              parts.push({ type: 'HEADER', text, format })
            else if type is 'BODY' && text
              parts.push({ type: 'BODY', text })
            else if type is 'FOOTER' && text
              parts.push({ type: 'FOOTER', text })
            else if type is 'BUTTONS' && !_.isEmpty(buttons)
              parts.push({ type: 'BUTTONS', buttons })
          return '' if _.isEmpty(parts)
          App.view('whatsapp/template_preview_fragment')(parts: parts)

      account = channel?.options?.name || __('WhatsApp')
      phone = channel?.options?.phone_number || '-'
      channelLabel = "#{account} (#{phone})"

      $target = $content.find('.page-content').first()
      $content.data('whatsappTemplates', data || [])
      $content.data('whatsappTemplatesChannelId', channelId)
      $target.html App.view('whatsapp/templates_list')(
        channelLabel: channelLabel
        templates: data || []
        statusClass: helpers.statusClass
        preview: helpers.preview
      )
    error: (xhr) =>
      $button.removeClass('is-loading is-active')
      response = {}
      try
        response = JSON.parse(xhr.responseText)
      catch error
        response = {}

      message = response.error_human || response.error || __('Unable to load WhatsApp templates.')
      App.Event.trigger 'notify',
        type: 'error'
        msg:  App.i18n.translateContent(message)
  )

# Admin: ChannelWhatsapp load keeps default render; sync uses global document handler above.
if typeof ChannelWhatsapp isnt 'undefined'
  ChannelWhatsapp.prototype.load = =>
    @startLoading()
    @ajax(
      id: 'whatsapp_index'
      type: 'GET'
      url: "#{@apiPath}/channels/admin/whatsapp"
      processData: true
      success: (data) =>
        @stopLoading()
        App.Collection.loadAssets(data.assets)
        @render(data)
    )

# Agent ticket create: support whatsapp-template-out in legacy UI.
if App.TicketCreate?
  App.TicketCreate.prototype.types[WHATSAPP_TEMPLATE_CREATE_TYPE] ?= {
    icon: 'whatsapp'
    label: __('WhatsApp template')
  }

  App.TicketCreate.prototype.articleSenderTypeMap[WHATSAPP_TEMPLATE_CREATE_TYPE] ?= {
    sender:  'Agent'
    article: 'whatsapp template message'
    title:   __('WhatsApp template')
    screen:  'create_phone_out'
  }

  _ticketCreateSetFormTypeInUi = App.TicketCreate.prototype.setFormTypeInUi
  App.TicketCreate.prototype.setFormTypeInUi = (type) ->
    _ticketCreateSetFormTypeInUi.apply(this, arguments)
    @scheduleWhatsappTemplateComposerRefresh()

  _ticketCreateRender = App.TicketCreate.prototype.render
  App.TicketCreate.prototype.render = (template = {}) ->
    _ticketCreateRender.apply(this, arguments)
    @registerWhatsappTemplateCoreWorkflowCallback()
    @scheduleWhatsappTemplateComposerRefresh()

  _ticketCreateSubmit = App.TicketCreate.prototype.submit
  App.TicketCreate.prototype.submit = (e) ->
    if @currentChannel() is WHATSAPP_TEMPLATE_CREATE_TYPE
      templateId = @$('.js-whatsapp-template-select').val()
      if !templateId
        App.Event.trigger 'notify',
          type: 'error'
          msg:  App.i18n.translateContent(__('Please select a WhatsApp template.'))
        return

      templateData = @whatsappTemplateFormData()
      customer = @$('[name=customer_id_completion]').val() || @$('[name=customer_id]').val() || ''
      title = templateData?.preferences?.name || __('WhatsApp template')
      if customer
        title = "#{title} (#{customer})"
      @$('[name=title]').val(title)

    _ticketCreateSubmit.apply(this, arguments)

  _ticketCreateArticleParams = App.TicketCreate.prototype.articleParams
  App.TicketCreate.prototype.articleParams = ->
    attributes = @articleAttributes || @articleSenderTypeMap?[@currentChannel()]
    return {} if !attributes

    params = @params()

    sender = App.TicketArticleSender.findByAttribute('name', attributes.sender)
    type   = App.TicketArticleType.findByAttribute('name', attributes.article)
    return {} if !sender || !type

    group = undefined
    if params.group_id
      group = App.Group.find(params.group_id)

    article = {}
    if sender.name is 'Customer'
      article = {
        to:           (group && group.name) || ''
        from:         params.customer_id_completion
        cc:           params.cc
        subject:      params.subject
        body:         params.body
        type_id:      type.id
        sender_id:    sender.id
        form_id:      @formId
        content_type: 'text/html'
      }
    else
      article = {
        from:         (group && group.name) || ''
        to:           params.customer_id_completion
        cc:           params.cc
        subject:      params.subject
        body:         params.body
        type_id:      type.id
        sender_id:    sender.id
        form_id:      @formId
        content_type: 'text/html'
      }

    if @securityOptionsShown()
      article.preferences ||= {}
      article.preferences.security = @paramsSecurity()

    if @currentChannel() isnt 'email-out'
      delete article.cc

    if @currentChannel() is WHATSAPP_TEMPLATE_CREATE_TYPE
      templateData = @whatsappTemplateFormData()
      if templateData
        article.content_type = 'text/plain'
        article.body = templateData.preview || article.body
        article.preferences ||= {}
        article.preferences.whatsapp_template = templateData.preferences

    article

  App.TicketCreate.prototype.scheduleWhatsappTemplateComposerRefresh = ->
    @delay =>
      @reapplyWhatsappTemplateFormLayoutIfNeeded()
    , 120, 'whatsapp-template-compose'

  App.TicketCreate.prototype.registerWhatsappTemplateCoreWorkflowCallback = ->
    return if @whatsappTemplateCoreWorkflowRegistered

    form = @controllerFormCreateMiddle
    return if !form

    @whatsappTemplateCoreWorkflowRegistered = true
    form.core_workflow ||= {}
    form.core_workflow.callbacks ||= []
    form.core_workflow.callbacks.push =>
      @reapplyWhatsappTemplateFormLayoutIfNeeded()

  App.TicketCreate.prototype.reapplyWhatsappTemplateFormLayoutIfNeeded = ->
    return if @currentChannel() isnt WHATSAPP_TEMPLATE_CREATE_TYPE

    @applyWhatsappTemplateFormLayout(true)
    @toggleWhatsappTemplateComposer(WHATSAPP_TEMPLATE_CREATE_TYPE)

  App.TicketCreate.prototype.bodyFieldGroup = ->
    @$('[data-name=body], [name=body]').closest('.form-group').first()

  App.TicketCreate.prototype.titleFieldGroup = ->
    @$('[name=title]').closest('.form-group').first()

  App.TicketCreate.prototype.applyWhatsappTemplateFormLayout = (enabled) ->
    $titleGroup = @titleFieldGroup()
    $bodyGroup = @bodyFieldGroup()
    $titleInput = @$('[name=title]')

    if enabled
      $titleGroup.addClass('hide').css('display', 'none')
      $bodyGroup.addClass('hide').css('display', 'none')
      $titleInput.prop('required', false).removeAttr('required')
      @$('.js-textModule, .js-textTools').closest('.form-group, .controls, .richtext-extended').addClass('hide').css('display', 'none')
    else
      $titleGroup.removeClass('hide').css('display', '')
      $bodyGroup.removeClass('hide').css('display', '')
      $titleInput.prop('required', true)
      @$('.js-textModule, .js-textTools').closest('.form-group, .controls, .richtext-extended').removeClass('hide').css('display', '')

  App.TicketCreate.prototype.collectWhatsappTemplateVariableValues = ->
    variableValues = {
      body: []
      header: []
      buttons: []
    }

    @$('.js-whatsapp-template-variable').each (idx, element) =>
      $element = $(element)
      section = $element.data('section')
      value = $element.val()
      index = parseInt($element.data('index'), 10)

      if section is 'body'
        variableValues.body[index] = value
      else if section is 'header'
        variableValues.header[index] = value
      else if "#{section}".match(/^buttons-(\d+)$/)
        buttonIndex = parseInt(section.replace('buttons-', ''), 10)
        variableValues.buttons[buttonIndex] ||= []
        variableValues.buttons[buttonIndex][index] = value

    variableValues

  App.TicketCreate.prototype.updateWhatsappTemplatePreview = ->
    $preview = @$('.js-whatsapp-template-preview')
    $content = @$('.js-whatsapp-template-preview-content')
    templateId = @$('.js-whatsapp-template-select').val()
    template = _.find(@whatsappTemplates || [], (item) -> "#{item.id}" is "#{templateId}")

    if !template
      $preview.addClass('hide')
      $content.text('')
      return

    preview = buildWhatsappTemplatePreviewText(template, @collectWhatsappTemplateVariableValues())
    $content.text(preview)
    $preview.removeClass('hide')

  App.TicketCreate.prototype.activeWhatsappChannels = ->
    (@whatsappChannelGroups || []).filter((entry) -> entry.active is true)

  App.TicketCreate.prototype.whatsappChannelLabel = (channel) ->
    account = channel.account_name || __('WhatsApp')
    phone = channel.phone_number || '-'
    group = channel.group_name || '-'
    "#{account} (#{phone}) — #{group}"

  App.TicketCreate.prototype.fetchWhatsappChannelGroups = (callback) ->
    if @whatsappChannelGroups
      callback(@whatsappChannelGroups)
      return

    @ajax(
      id: 'whatsapp_channel_groups'
      type: 'GET'
      url: "#{@apiPath}/whatsapp_message_templates/channel_groups"
      success: (data) =>
        @whatsappChannelGroups = data || []
        callback(@whatsappChannelGroups)
      error: =>
        @whatsappChannelGroups = []
        callback(@whatsappChannelGroups)
    )

  App.TicketCreate.prototype.updateWhatsappTemplateHint = (groupId) ->
    $hint = @$('.js-whatsapp-template-hint')

    @fetchWhatsappChannelGroups (groups) =>
      availableGroups = _.uniq(_.compact(groups.map((entry) -> entry.group_name))).join(', ')

      if availableGroups
        $hint.text App.i18n.translatePlain(__('No WhatsApp channel for this group. Groups with WhatsApp: %{groups}', availableGroups))
      else
        $hint.text App.i18n.translatePlain(__('No WhatsApp channel found. Configure one in Admin → Channels → WhatsApp and sync templates first.'))

  App.TicketCreate.prototype.populateWhatsappChannelSelect = (groupId) ->
    $channelGroup = @$('.js-whatsapp-channel-group')
    $channelSelect = @$('.js-whatsapp-channel-select')
    channels = @activeWhatsappChannels()

    $channelSelect.find('option').remove()

    if !channels.length
      $channelGroup.addClass('hide')
      return

    preferredChannelId = undefined
    if groupId
      groupChannel = _.find(channels, (entry) -> "#{entry.group_id}" is "#{groupId}")
      preferredChannelId = groupChannel?.channel_id

    for channel in channels
      selected = if preferredChannelId then "#{channel.channel_id}" is "#{preferredChannelId}" else false
      selectedAttr = if selected then ' selected' else ''
      label = @whatsappChannelLabel(channel)
      $channelSelect.append("<option value=\"#{channel.channel_id}\"#{selectedAttr}>#{App.Utils.htmlEscape(label)}</option>")

    if !preferredChannelId && channels.length is 1
      $channelSelect.find('option:first').prop('selected', true)

    if channels.length > 1
      $channelGroup.removeClass('hide')
    else
      $channelGroup.addClass('hide')

  App.TicketCreate.prototype.selectedWhatsappChannelId = ->
    @$('.js-whatsapp-channel-select').val()

  App.TicketCreate.prototype.syncTicketGroupWithWhatsappChannel = (channelId) ->
    return if !channelId

    channel = _.find(@activeWhatsappChannels(), (entry) -> "#{entry.channel_id}" is "#{channelId}")
    return if !channel

    currentGroupId = @$('[name=group_id]').val()
    return if "#{currentGroupId}" is "#{channel.group_id}"

    @$('[name=group_id]').val(channel.group_id).trigger('change', non_interactive: true)

  App.TicketCreate.prototype.toggleWhatsappTemplateComposer = (type) ->
    type ||= @currentChannel()
    $bodyGroup = @bodyFieldGroup()
    $container = @$('.js-whatsapp-template-composer')

    if type isnt WHATSAPP_TEMPLATE_CREATE_TYPE
      @$('[name=group_id]').off('change.whatsappTemplate')
      $container.remove()
      @applyWhatsappTemplateFormLayout(false)
      return

    @applyWhatsappTemplateFormLayout(true)

    if !$container.length
      $target = @$('.article-form-top')
      $target = $bodyGroup.parent() if !$target.length

      $target.append(
        """
        <div class="form-group js-whatsapp-template-composer">
          <div class="form-group js-whatsapp-channel-group hide">
            <div class="formGroup-label"><label>#{App.i18n.translatePlain(__('WhatsApp Account'))}</label></div>
            <select class="form-control js-whatsapp-channel-select"></select>
          </div>
          <div class="form-group">
            <div class="formGroup-label"><label>#{App.i18n.translatePlain(__('WhatsApp Template'))}</label></div>
            <select class="form-control js-whatsapp-template-select">
              <option value="">#{App.i18n.translatePlain(__('Select template'))}</option>
            </select>
          </div>
          <div class="form-group js-whatsapp-template-preview hide">
            <div class="formGroup-label"><label>#{App.i18n.translatePlain(__('Template preview'))}</label></div>
            <div class="well well--no-border js-whatsapp-template-preview-content"></div>
          </div>
          <div class="js-whatsapp-template-variables u-mt"></div>
          <p class="help-block js-whatsapp-template-hint"></p>
        </div>
        """
      )

      @$('[name=group_id]').off('change.whatsappTemplate').on 'change.whatsappTemplate', =>
        return if @currentChannel() isnt WHATSAPP_TEMPLATE_CREATE_TYPE
        @fetchWhatsappChannelGroups =>
          @populateWhatsappChannelSelect(@$('[name=group_id]').val())
          @loadWhatsappTemplatesForCreate()

      @$('.js-whatsapp-channel-select').off('change.whatsappTemplate').on 'change.whatsappTemplate', (e) =>
        channelId = $(e.currentTarget).val()
        @syncTicketGroupWithWhatsappChannel(channelId)
        @loadWhatsappTemplatesForCreate()

      @$('.js-whatsapp-template-select').off('change.whatsappTemplate').on 'change.whatsappTemplate', (e) =>
        @renderWhatsappTemplateVariables($(e.currentTarget).val())

      @$('.js-whatsapp-template-variables').off('input.whatsappTemplate').on 'input.whatsappTemplate', '.js-whatsapp-template-variable', =>
        @updateWhatsappTemplatePreview()

    @fetchWhatsappChannelGroups =>
      @populateWhatsappChannelSelect(@$('[name=group_id]').val())
      @loadWhatsappTemplatesForCreate()

  App.TicketCreate.prototype.loadWhatsappTemplatesForCreate = ->
    return if @currentChannel() isnt WHATSAPP_TEMPLATE_CREATE_TYPE

    groupId = @$('[name=group_id]').val()
    channelId = @selectedWhatsappChannelId()
    $select = @$('.js-whatsapp-template-select')
    $hint = @$('.js-whatsapp-template-hint')

    @whatsappTemplates = []
    $select.find('option:not(:first)').remove()
    $hint.text('')
    @$('.js-whatsapp-template-variables').empty()
    @updateWhatsappTemplatePreview()

    return if !groupId && !channelId

    if !channelId
      @updateWhatsappTemplateHint(groupId)
      return

    @ajax(
      id: 'whatsapp_templates_list'
      type: 'GET'
      url: "#{@apiPath}/whatsapp_message_templates?channel_id=#{channelId}&status=APPROVED"
      success: (data) =>
        @whatsappTemplates = data || []
        for template in @whatsappTemplates
          label = "#{template.name} (#{template.language})"
          $select.append("<option value=\"#{template.id}\">#{App.Utils.htmlEscape(label)}</option>")

        return if @whatsappTemplates.length

        $hint.text App.i18n.translatePlain(__('No templates found for this WhatsApp account. Click Sync Templates in Admin → Channels → WhatsApp first.'))
      error: (xhr) =>
        response = {}
        try
          response = JSON.parse(xhr.responseText)
        catch error
          response = {}
        $hint.text App.i18n.translateContent(response.error_human || response.error || __('Unable to load WhatsApp templates.'))
    )

  App.TicketCreate.prototype.renderWhatsappTemplateVariables = (templateId) ->
    $container = @$('.js-whatsapp-template-variables')
    $container.empty()

    template = _.find(@whatsappTemplates || [], (item) -> "#{item.id}" is "#{templateId}")
    if !template
      @updateWhatsappTemplatePreview()
      return

    variables = template.variables || {}

    renderFields = (items, section, labelPrefix) =>
      return if _.isEmpty(items)

      $section = $('<div class="form-group"></div>')
      $section.append("<div class=\"formGroup-label\"><label>#{App.Utils.htmlEscape(labelPrefix)}</label></div>")
      for item, index in items
        position = item.position || index + 1
        $section.append(
          """
          <input type="text" class="form-control js-whatsapp-template-variable u-mb"
            data-section="#{section}" data-index="#{index}" placeholder="#{App.Utils.htmlEscape(item.label || "Variable #{position}")}">
          """
        )
      $container.append($section)

    renderFields(variables.header, 'header', __('Header variables'))
    renderFields(variables.body, 'body', __('Body variables'))

    if !_.isEmpty(variables.buttons)
      for buttonVariables, buttonIndex in variables.buttons
        renderFields(buttonVariables, "buttons-#{buttonIndex}", __('Button variables'))

    @updateWhatsappTemplatePreview()

  App.TicketCreate.prototype.whatsappTemplateFormData = ->
    templateId = @$('.js-whatsapp-template-select').val()
    return if !templateId

    template = _.find(@whatsappTemplates || [], (item) -> "#{item.id}" is "#{templateId}")
    return if !template

    channelId = @selectedWhatsappChannelId()
    if channelId
      template.channel_id = parseInt(channelId, 10)

    variableValues = @collectWhatsappTemplateVariableValues()

    preview = buildWhatsappTemplatePreviewText(template, variableValues)

    componentsJson = []
    if variableValues.body.some((value) -> !_.isEmpty(value))
      componentsJson.push({
        type: 'body'
        parameters: _.compact(variableValues.body).map((text) -> { type: 'text', text })
      })

    if variableValues.header.some((value) -> !_.isEmpty(value))
      componentsJson.push({
        type: 'header'
        parameters: _.compact(variableValues.header).map((text) -> { type: 'text', text })
      })

    for buttonValues, buttonIndex in variableValues.buttons
      continue if !buttonValues?.some((value) -> !_.isEmpty(value))
      componentsJson.push({
        type: 'button'
        sub_type: 'url'
        index: "#{buttonIndex}"
        parameters: _.compact(buttonValues).map((text) -> { type: 'text', text })
      })

    {
      preview: preview
      preferences: {
        template_id: template.id
        name: template.name
        language: template.language
        variable_values: variableValues
        components_json: componentsJson
        channel_id: template.channel_id
      }
    }

# Agent ticket zoom: send WhatsApp templates in open conversations.
if App.TicketZoomArticleNew?
  sharedWhatsappTemplateMethods = [
    'collectWhatsappTemplateVariableValues'
    'updateWhatsappTemplatePreview'
    'renderWhatsappTemplateVariables'
  ]

  for methodName in sharedWhatsappTemplateMethods
    App.TicketZoomArticleNew.prototype[methodName] = App.TicketCreate.prototype[methodName]

  _articleNewSetArticleTypePre = App.TicketZoomArticleNew.prototype.setArticleTypePre
  App.TicketZoomArticleNew.prototype.setArticleTypePre = (type, signaturePosition = 'bottom') ->
    previousType = @type
    _articleNewSetArticleTypePre.apply(this, arguments)

    if previousType is WHATSAPP_TEMPLATE_ARTICLE_TYPE && type isnt WHATSAPP_TEMPLATE_ARTICLE_TYPE
      @toggleWhatsappTemplateZoomComposer(false)

    if type is WHATSAPP_TEMPLATE_ARTICLE_TYPE
      @toggleWhatsappTemplateZoomComposer(true)

  _articleNewValidate = App.TicketZoomArticleNew.prototype.validate
  App.TicketZoomArticleNew.prototype.validate = ->
    if @type is WHATSAPP_TEMPLATE_ARTICLE_TYPE
      templateId = @$('.js-whatsapp-template-select').val()
      if !templateId
        App.Event.trigger 'notify',
          type: 'error'
          msg:  App.i18n.translateContent(__('Please select a WhatsApp template.'))
        return false

      templateData = @whatsappTemplateFormData()
      if templateData
        @$('.js-textarea [data-name=body]').text(templateData.preview)

    _articleNewValidate.apply(this, arguments)

  _articleNewParams = App.TicketZoomArticleNew.prototype.params
  App.TicketZoomArticleNew.prototype.params = ->
    if @type is WHATSAPP_TEMPLATE_ARTICLE_TYPE
      templateData = @whatsappTemplateFormData()
      if templateData
        @$('.js-textarea [data-name=body]').text(templateData.preview)

    params = _articleNewParams.apply(this, arguments)

    if @type is WHATSAPP_TEMPLATE_ARTICLE_TYPE or params.preferences?.whatsapp_template
      articleType = App.TicketArticleType.findByAttribute('name', WHATSAPP_TEMPLATE_ARTICLE_TYPE)
      sender = App.TicketArticleSender.findByAttribute('name', 'Agent')

      if articleType
        params.type_id = articleType.id
        params.type = WHATSAPP_TEMPLATE_ARTICLE_TYPE
      if sender
        params.sender_id = sender.id

      templateData = @whatsappTemplateFormData?()
      if templateData
        params.content_type = 'text/plain'
        params.body = templateData.preview || params.body
        params.preferences ||= {}
        params.preferences.whatsapp_template = templateData.preferences

    params

  App.TicketZoomArticleNew.prototype.whatsappTemplateChannelId = ->
    App.Ticket.fullLocal(@ticket_id)?.preferences?.channel_id

  App.TicketZoomArticleNew.prototype.applyWhatsappTemplateZoomLayout = (enabled) ->
    $textBubble = @$('.textBubble')
    $textarea = @$('.js-textarea')
    $attachments = @$('.article-attachment, .attachments, .attachmentPlaceholder, .js-textSizeLimit')

    if enabled
      $textarea.addClass('hide').css('display', 'none')
      $attachments.addClass('hide').css('display', 'none')
      @$('.js-textModule, .js-textTools').addClass('hide').css('display', 'none')
    else
      $textarea.removeClass('hide').css('display', '')
      $attachments.removeClass('hide').css('display', '')
      @$('.js-textModule, .js-textTools').removeClass('hide').css('display', '')

  App.TicketZoomArticleNew.prototype.toggleWhatsappTemplateZoomComposer = (enabled) ->
    $container = @$('.js-whatsapp-template-composer')

    if !enabled
      $container.remove()
      @applyWhatsappTemplateZoomLayout(false)
      return

    @applyWhatsappTemplateZoomLayout(true)

    if !$container.length
      $target = @$('.textBubble')
      $target.prepend(
        """
        <div class="form-group js-whatsapp-template-composer">
          <div class="form-group">
            <div class="formGroup-label"><label>#{App.i18n.translatePlain(__('WhatsApp Template'))}</label></div>
            <select class="form-control js-whatsapp-template-select">
              <option value="">#{App.i18n.translatePlain(__('Select template'))}</option>
            </select>
          </div>
          <div class="form-group js-whatsapp-template-preview hide">
            <div class="formGroup-label"><label>#{App.i18n.translatePlain(__('Template preview'))}</label></div>
            <div class="well well--no-border js-whatsapp-template-preview-content"></div>
          </div>
          <div class="js-whatsapp-template-variables u-mt"></div>
          <p class="help-block js-whatsapp-template-hint"></p>
        </div>
        """
      )

      @$('.js-whatsapp-template-select').off('change.whatsappTemplateZoom').on 'change.whatsappTemplateZoom', (e) =>
        @renderWhatsappTemplateVariables($(e.currentTarget).val())

      @$('.js-whatsapp-template-variables').off('input.whatsappTemplateZoom').on 'input.whatsappTemplateZoom', '.js-whatsapp-template-variable', =>
        @updateWhatsappTemplatePreview()

    @loadWhatsappTemplatesForZoom()

  App.TicketZoomArticleNew.prototype.loadWhatsappTemplatesForZoom = ->
    channelId = @whatsappTemplateChannelId()
    $select = @$('.js-whatsapp-template-select')
    $hint = @$('.js-whatsapp-template-hint')

    @whatsappTemplates = []
    $select.find('option:not(:first)').remove()
    $hint.text('')
    @$('.js-whatsapp-template-variables').empty()
    @updateWhatsappTemplatePreview()

    return if !channelId

    @ajax(
      id: 'whatsapp_templates_zoom_list'
      type: 'GET'
      url: "#{@apiPath}/whatsapp_message_templates?channel_id=#{channelId}&status=APPROVED"
      success: (data) =>
        @whatsappTemplates = data || []
        for template in @whatsappTemplates
          label = "#{template.name} (#{template.language})"
          $select.append("<option value=\"#{template.id}\">#{App.Utils.htmlEscape(label)}</option>")

        return if @whatsappTemplates.length

        $hint.text App.i18n.translatePlain(__('No templates found for this WhatsApp account. Click Sync Templates in Admin → Channels → WhatsApp first.'))
      error: (xhr) =>
        response = {}
        try
          response = JSON.parse(xhr.responseText)
        catch error
          response = {}
        $hint.text App.i18n.translateContent(response.error_human || response.error || __('Unable to load WhatsApp templates.'))
    )

  App.TicketZoomArticleNew.prototype.whatsappTemplateFormData = ->
    templateId = @$('.js-whatsapp-template-select').val()
    return if !templateId

    template = _.find(@whatsappTemplates || [], (item) -> "#{item.id}" is "#{templateId}")
    return if !template

    channelId = @whatsappTemplateChannelId()
    if channelId
      template.channel_id = parseInt(channelId, 10)

    variableValues = @collectWhatsappTemplateVariableValues()
    preview = buildWhatsappTemplatePreviewText(template, variableValues)

    componentsJson = []
    if variableValues.body.some((value) -> !_.isEmpty(value))
      componentsJson.push({
        type: 'body'
        parameters: _.compact(variableValues.body).map((text) -> { type: 'text', text })
      })

    if variableValues.header.some((value) -> !_.isEmpty(value))
      componentsJson.push({
        type: 'header'
        parameters: _.compact(variableValues.header).map((text) -> { type: 'text', text })
      })

    for buttonValues, buttonIndex in variableValues.buttons
      continue if !buttonValues?.some((value) -> !_.isEmpty(value))
      componentsJson.push({
        type: 'button'
        sub_type: 'url'
        index: "#{buttonIndex}"
        parameters: _.compact(buttonValues).map((text) -> { type: 'text', text })
      })

    {
      preview: preview
      preferences: {
        template_id: template.id
        name: template.name
        language: template.language
        variable_values: variableValues
        components_json: componentsJson
        channel_id: template.channel_id
      }
    }
