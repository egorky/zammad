# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'

whatsappTemplateApiPath = ->
  App.Config.get('api_path') || '/api/v1'

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
    @scheduleWhatsappTemplateComposerRefresh()

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
      @toggleWhatsappTemplateComposer(@currentChannel())
    , 120, 'whatsapp-template-compose'

  App.TicketCreate.prototype.bodyFieldGroup = ->
    @$('[data-name=body], [name=body]').closest('.form-group').first()

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
      $bodyGroup.removeClass('hide')
      return

    $bodyGroup.addClass('hide')

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
    return if !template

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

    renderFields(variables.body, 'body', __('Body variables'))
    renderFields(variables.header, 'header', __('Header variables'))

    if !_.isEmpty(variables.buttons)
      for buttonVariables, buttonIndex in variables.buttons
        renderFields(buttonVariables, "buttons-#{buttonIndex}", __('Button variables'))

  App.TicketCreate.prototype.whatsappTemplateFormData = ->
    templateId = @$('.js-whatsapp-template-select').val()
    return if !templateId

    template = _.find(@whatsappTemplates || [], (item) -> "#{item.id}" is "#{templateId}")
    return if !template

    channelId = @selectedWhatsappChannelId()
    if channelId
      template.channel_id = parseInt(channelId, 10)

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

    preview = template.name
    bodyComponent = _.find(template.components || [], (component) -> "#{component.type}".toUpperCase() is 'BODY')
    if bodyComponent?.text
      preview = bodyComponent.text
      for value, index in variableValues.body
        preview = preview.replace("{{#{index + 1}}}", value || "{{#{index + 1}}}")

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
