# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Extends the legacy admin WhatsApp channel screen with template sync actions.
if typeof ChannelWhatsapp isnt 'undefined'
  ChannelWhatsapp.prototype.events ||= {}
  ChannelWhatsapp.prototype.events['click .js-sync-whatsapp-templates'] = 'syncWhatsappTemplates'

  _render = ChannelWhatsapp.prototype.render
  ChannelWhatsapp.prototype.render = (data) ->
    _render.apply(this, arguments)
    @injectWhatsappTemplateSyncButtons()

  ChannelWhatsapp.prototype.injectWhatsappTemplateSyncButtons = ->
    @$('.action[data-id]').each (idx, element) =>
      $element = $(element)
      return if $element.find('.js-sync-whatsapp-templates').length

      channelId = $element.data('id')
      $element.find('.action-controls').prepend(
        "<button type=\"button\" class=\"btn btn--secondary js-sync-whatsapp-templates\" data-id=\"#{channelId}\">#{App.i18n.translatePlain('Sync Templates')}</button>"
      )

  ChannelWhatsapp.prototype.syncWhatsappTemplates = (e) ->
    e.preventDefault()

    channelId = $(e.currentTarget).data('id')
    return if !channelId

    @startLoading()
    @ajax(
      id: 'whatsapp_templates_sync'
      type: 'POST'
      url: "#{@apiPath}/whatsapp_message_templates/sync"
      data: JSON.stringify(channel_id: channelId)
      processData: true
      success: (data) =>
        @stopLoading()
        App.Event.trigger 'notify',
          type: 'success'
          msg:  App.i18n.translateContent(data.message || __('WhatsApp templates synchronized successfully.'))
      error: (xhr) =>
        @stopLoading()
        response = {}
        try
          response = JSON.parse(xhr.responseText)
        catch error
          response = {}

        App.Event.trigger 'notify',
          type: 'error'
          msg:  App.i18n.translateContent(response.error || response.error_human || __('Unable to sync WhatsApp templates.'))
    )
