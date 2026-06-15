// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

WHATSAPP_OUTBOUND_ARTICLE_TYPES = ['whatsapp message', 'whatsapp template message']

whatsappTemplateStatusClass = (status) ->
  normalized = "#{status}".toUpperCase()
  switch normalized
    when 'APPROVED' then 'success'
    when 'PENDING', 'IN_APPEAL' then 'warning'
    when 'REJECTED', 'PAUSED', 'DISABLED' then 'danger'
    else 'muted'

buildWhatsappTemplateDisplayParts = (template) ->
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

  parts

renderWhatsappTemplatePreviewFragment = (template) ->
  parts = buildWhatsappTemplateDisplayParts(template)
  return '' if _.isEmpty(parts)

  App.view('whatsapp/template_preview_fragment')(
    parts: parts
  )

renderWhatsappTemplatePreviewHtml = (template) ->
  preview = buildWhatsappTemplatePreviewText(template)
  return App.Utils.htmlEscape(preview) if preview

  App.Utils.htmlEscape(template?.name || '')

whatsappTemplateChannelLabel = (channel) ->
  return __('WhatsApp') if !channel

  account = channel.options?.name || __('WhatsApp')
  phone = channel.options?.phone_number || '-'
  "#{account} (#{phone})"

buildWhatsappArticleDeliveryStatus = (article) ->
  return { show: false } if !article
  return { show: false } if article.sender?.name isnt 'Agent'
  return { show: false } if WHATSAPP_OUTBOUND_ARTICLE_TYPES.indexOf(article.type?.name) is -1

  preferences = article.preferences || {}
  whatsapp = preferences.whatsapp || {}

  if preferences.delivery_status is 'fail' || whatsapp.delivery_status is 'fail'
    return {
      show: true
      failed: true
      message: preferences.delivery_status_message || whatsapp.delivery_status_message || ''
    }

  if whatsapp.timestamp_read
    return { show: true, read: true, label: __('Read') }
  if whatsapp.timestamp_delivered
    return { show: true, delivered: true, label: __('Delivered') }
  if whatsapp.timestamp_sent || whatsapp.message_id
    return { show: true, sent: true, label: __('Sent') }

  { show: false }

appendWhatsappArticleDeliveryStatus = (controller, article) ->
  status = buildWhatsappArticleDeliveryStatus(article)
  return if !status.show

  html = App.view('ticket_zoom/article_whatsapp_delivery_status')(
    status: status
  )

  $bubble = controller.$('.textBubble').first()
  return if !$bubble.length

  $bubble.find('.article-whatsapp-delivery-status').remove()
  $bubble.append(html)

if typeof ChannelWhatsapp isnt 'undefined'
  ChannelWhatsapp::events['click .js-view-whatsapp-templates'] = 'viewWhatsappTemplates'
  ChannelWhatsapp::events['click .js-back-whatsapp-accounts'] = 'backToWhatsappAccounts'
  ChannelWhatsapp::events['click .js-back-whatsapp-templates'] = 'backToWhatsappTemplates'
  ChannelWhatsapp::events['click .js-whatsapp-template-card'] = 'openWhatsappTemplateDetail'

  _channelWhatsappRender = ChannelWhatsapp.prototype.render
  ChannelWhatsapp.prototype.render = (data) ->
    @whatsappTemplatesChannelId = null
    @whatsappTemplates = null
    @whatsappTemplatesChannel = null
    _channelWhatsappRender.apply(this, arguments)
    @el.attr('data-whatsapp-channel-controller', 'true')
    @el.data('whatsappChannelController', this)

  ChannelWhatsapp.prototype.whatsappTemplateViewHelpers = ->
    statusClass: whatsappTemplateStatusClass
    preview: (template) -> renderWhatsappTemplatePreviewFragment(template)
    variablesSummary: (variables) -> formatWhatsappTemplateVariablesSummary(variables)

  ChannelWhatsapp.prototype.viewWhatsappTemplates = (e) ->
    e.preventDefault()
    e.stopPropagation()

    $button = $(e.currentTarget)
    channelId = $button.attr('data-id')
    return if !channelId
    return if $button.hasClass('is-loading')

    @loadWhatsappTemplates(channelId, $button)

  ChannelWhatsapp.prototype.loadWhatsappTemplates = (channelId, $button) ->
    $button?.addClass('is-loading is-active')

    App.Ajax.request(
      id: 'whatsapp_templates_view'
      type: 'GET'
      url: "#{@apiPath}/whatsapp_message_templates?channel_id=#{channelId}"
      success: (data) =>
        $button?.removeClass('is-loading is-active')
        @whatsappTemplatesChannelId = channelId
        @whatsappTemplatesChannel = App.Channel.find(channelId)
        @whatsappTemplates = data || []
        @renderWhatsappTemplatesList()
      error: (xhr) =>
        $button?.removeClass('is-loading is-active')
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

  ChannelWhatsapp.prototype.renderWhatsappTemplatesList = ->
    helpers = @whatsappTemplateViewHelpers()

    @html App.view('whatsapp/templates_list')(
      channelLabel: whatsappTemplateChannelLabel(@whatsappTemplatesChannel)
      templates: @whatsappTemplates || []
      statusClass: helpers.statusClass
      preview: helpers.preview
    )
    @el.data('whatsappChannelController', this)

  ChannelWhatsapp.prototype.openWhatsappTemplateDetail = (e) ->
    e.preventDefault()
    e.stopPropagation()

    templateId = $(e.currentTarget).closest('.js-whatsapp-template-card').attr('data-id')
    return if !templateId

    template = _.find(@whatsappTemplates || [], (item) -> "#{item.id}" is "#{templateId}")
    return if !template

    @renderWhatsappTemplateDetail(template)

  ChannelWhatsapp.prototype.renderWhatsappTemplateDetail = (template) ->
    helpers = @whatsappTemplateViewHelpers()

    @html App.view('whatsapp/template_detail')(
      template: template
      channelLabel: whatsappTemplateChannelLabel(@whatsappTemplatesChannel)
      statusClass: helpers.statusClass
      preview: helpers.preview
      variablesSummary: helpers.variablesSummary
    )
    @el.data('whatsappChannelController', this)

  ChannelWhatsapp.prototype.backToWhatsappAccounts = (e) ->
    e.preventDefault()
    @load()

  ChannelWhatsapp.prototype.backToWhatsappTemplates = (e) ->
    e.preventDefault()
    return @load() if !@whatsappTemplatesChannelId
    @renderWhatsappTemplatesList()

if App.ArticleViewItem?
  _articleViewItemRender = App.ArticleViewItem.prototype.render
  App.ArticleViewItem.prototype.render = (article) ->
    if article.preferences?.whatsapp
      icon = null
      msg  = null
      if article.preferences?.whatsapp?.timestamp_read
        icon = 'double-checkmark'
        msg  = __('read by the customer')
      else if article.preferences?.whatsapp?.timestamp_delivered
        icon = 'double-checkmark-outline'
        msg  = __('delivered to the customer')
      else if article.preferences?.whatsapp?.timestamp_sent || article.preferences?.whatsapp?.message_id
        icon = 'checkmark-outline'
        msg  = __('sent to the customer')

      article['delivery_status_icon']    = icon
      article['delivery_status_message'] = msg

    _articleViewItemRender.apply(this, arguments)
    appendWhatsappArticleDeliveryStatus(this, article)

findWhatsappChannelController = ($context) ->
  $content = $context?.closest('.content')
  return unless $content?.length

  $content.find('[data-whatsapp-channel-controller]').data('whatsappChannelController') ||
    $content.data('whatsappChannelController')

$(document).off('click.whatsappTemplateBack').on 'click.whatsappTemplateBack', '.js-back-whatsapp-accounts', (e) ->
  e.preventDefault()
  controller = findWhatsappChannelController($(e.currentTarget))
  if controller?.load
    controller.load()
    return

  window.location.hash = '#channels/whatsapp'

$(document).off('click.whatsappTemplateListBack').on 'click.whatsappTemplateListBack', '.js-back-whatsapp-templates', (e) ->
  e.preventDefault()
  controller = findWhatsappChannelController($(e.currentTarget))
  if controller?.backToWhatsappTemplates
    controller.backToWhatsappTemplates(e)

$(document).off('click.whatsappTemplateOpen').on 'click.whatsappTemplateOpen', '.js-whatsapp-template-card', (e) ->
  e.preventDefault()
  controller = findWhatsappChannelController($(e.currentTarget))
  if controller?.openWhatsappTemplateDetail
    controller.openWhatsappTemplateDetail(e)
    return

  $content = $(e.currentTarget).closest('.content')
  templates = $content.data('whatsappTemplates')
  channelId = $content.data('whatsappTemplatesChannelId')
  return if _.isEmpty(templates) || !channelId

  templateId = $(e.currentTarget).closest('.js-whatsapp-template-card').attr('data-id')
  template = _.find(templates, (item) -> "#{item.id}" is "#{templateId}")
  return if !template

  channel = App.Channel.find(channelId)
  account = channel?.options?.name || __('WhatsApp')
  phone = channel?.options?.phone_number || '-'
  channelLabel = "#{account} (#{phone})"

  helpers =
    statusClass: whatsappTemplateStatusClass
    preview: (item) -> renderWhatsappTemplatePreviewFragment(item)
    variablesSummary: (variables) -> formatWhatsappTemplateVariablesSummary(variables)

  $content.find('.page-content').first().html App.view('whatsapp/template_detail')(
    template: template
    channelLabel: channelLabel
    statusClass: helpers.statusClass
    preview: helpers.preview
    variablesSummary: helpers.variablesSummary
  )
