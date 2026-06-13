# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

WHATSAPP_TEMPLATE_CREATE_TYPE = 'whatsapp-template-out'

# Admin: sync templates button handler on WhatsApp channel settings.
if typeof ChannelWhatsapp isnt 'undefined'
  ChannelWhatsapp.prototype.syncWhatsappTemplates = (e) ->
    e.preventDefault()
    e.stopPropagation()

    $button = $(e.currentTarget)
    channelId = $button.attr('data-id')
    return if !channelId
    return if $button.hasClass('is-loading')

    $button.addClass('is-loading is-active')

    @ajax(
      id: 'whatsapp_templates_sync'
      type: 'POST'
      url: "#{@apiPath}/whatsapp_message_templates/sync"
      data: JSON.stringify({ channel_id: channelId })
      success: (data) =>
        $button.removeClass('is-loading is-active')
        @showWhatsappTemplateSyncResult(data)
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

  ChannelWhatsapp.prototype.showWhatsappTemplateSyncResult = (data) ->
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

    new App.ControllerConfirm(
      head: __('WhatsApp Templates')
      message: message
      buttonSubmit: __('OK')
      buttonCancel: false
      buttonClass: 'btn--primary'
      callback: =>
      container: @el.closest('.content')
    )

  ChannelWhatsapp.prototype.bindWhatsappTemplateSyncButtons = ->
    @$('.js-sync-whatsapp-templates').off('click.whatsappTemplateSync').on 'click.whatsappTemplateSync', (e) =>
      @syncWhatsappTemplates(e)

  _channelWhatsappLoad = ChannelWhatsapp.prototype.load
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
        @bindWhatsappTemplateSyncButtons()
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

  App.TicketCreate.prototype.whatsappChannelGroupsHint = (callback) ->
    @fetchWhatsappChannelGroups (groups) =>
      names = _.uniq(_.compact(groups.map((entry) -> entry.group_name)))
      callback(names.join(', '))

  App.TicketCreate.prototype.updateWhatsappTemplateHint = (groupId) ->
    $hint = @$('.js-whatsapp-template-hint')

    @fetchWhatsappChannelGroups (groups) =>
      availableGroups = _.uniq(_.compact(groups.map((entry) -> entry.group_name))).join(', ')

      if availableGroups
        $hint.text App.i18n.translatePlain(__('No WhatsApp channel for this group. Groups with WhatsApp: %{groups}', availableGroups))
      else
        $hint.text App.i18n.translatePlain(__('No WhatsApp channel found. Configure one in Admin → Channels → WhatsApp and sync templates first.'))

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
          <div class="formGroup-label"><label>#{App.i18n.translatePlain(__('WhatsApp Template'))}</label></div>
          <select class="form-control js-whatsapp-template-select">
            <option value="">#{App.i18n.translatePlain(__('Select template'))}</option>
          </select>
          <div class="js-whatsapp-template-variables u-mt"></div>
          <p class="help-block js-whatsapp-template-hint"></p>
        </div>
        """
      )

      @$('[name=group_id]').off('change.whatsappTemplate').on 'change.whatsappTemplate', =>
        return if @currentChannel() isnt WHATSAPP_TEMPLATE_CREATE_TYPE
        @loadWhatsappTemplatesForCreate()

      @$('.js-whatsapp-template-select').off('change.whatsappTemplate').on 'change.whatsappTemplate', (e) =>
        @renderWhatsappTemplateVariables($(e.currentTarget).val())

    @loadWhatsappTemplatesForCreate()

  App.TicketCreate.prototype.loadWhatsappTemplatesForCreate = ->
    return if @currentChannel() isnt WHATSAPP_TEMPLATE_CREATE_TYPE

    groupId = @$('[name=group_id]').val()
    $select = @$('.js-whatsapp-template-select')
    $hint = @$('.js-whatsapp-template-hint')

    @whatsappTemplates = []
    $select.find('option:not(:first)').remove()
    $hint.text('')

    return if !groupId

    @ajax(
      id: 'whatsapp_templates_list'
      type: 'GET'
      url: "#{@apiPath}/whatsapp_message_templates?group_id=#{groupId}&status=APPROVED"
      success: (data) =>
        @whatsappTemplates = data || []
        for template in @whatsappTemplates
          label = "#{template.name} (#{template.language})"
          $select.append("<option value=\"#{template.id}\">#{App.Utils.htmlEscape(label)}</option>")

        return if @whatsappTemplates.length

        @fetchWhatsappChannelGroups (groups) =>
          groupEntry = _.find(groups, (entry) -> "#{entry.group_id}" is "#{groupId}")
          if groupEntry
            $hint.text App.i18n.translatePlain(__('No templates found for this WhatsApp channel. Click Sync Templates in Admin → Channels → WhatsApp first.'))
          else
            @updateWhatsappTemplateHint(groupId)
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
