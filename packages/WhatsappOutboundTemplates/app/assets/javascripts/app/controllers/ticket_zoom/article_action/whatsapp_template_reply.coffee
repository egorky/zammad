# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME = 'whatsapp template message'

class WhatsappTemplateReply
  @isWhatsappTicket: (ticket) ->
    return false if !ticket?.preferences?.whatsapp
    return false if !ticket?.create_article_type_id

    articleTypeCreate = App.TicketArticleType.find(ticket.create_article_type_id)?.name
    articleTypeCreate is 'whatsapp message'

  @action: (actions, ticket, article, ui) ->
    return actions if !ticket.editable()
    return actions if ticket.currentView() is 'customer'
    return actions if !@isWhatsappTicket(ticket)
    return actions if _.find(actions, (entry) -> entry.type is 'whatsappTemplateReply')

    actions.push {
      name: __('Send template')
      type: 'whatsappTemplateReply'
      icon: 'whatsapp'
      href: '#'
    }

    actions

  @perform: (articleContainer, type, ticket, article, ui) ->
    return true if type isnt 'whatsappTemplateReply'

    ui.scrollToCompose()

    articleType = App.TicketArticleType.findByAttribute('name', WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME)

    App.Event.trigger('ui::ticket::setArticleType', {
      ticket:  ticket
      type:    articleType
      article: {
        to:          ''
        cc:          ''
        body:        ''
        in_reply_to: ''
      }
    })

    true

  @articleTypes: (articleTypes, ticket, ui) ->
    return articleTypes if ticket.currentView() is 'customer'
    return articleTypes if !@isWhatsappTicket(ticket)

    articleTypes.push {
      name:       WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME
      icon:       'whatsapp'
      attributes: []
      internal:   false
      features:   []
    }

    articleTypes

  @params: (type, params, ui) ->
    if type is WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME
      templateData = ui.whatsappTemplateFormData?()
      if templateData
        params.content_type = 'text/plain'
        params.body = templateData.preview || ''
        params.preferences ||= {}
        params.preferences.whatsapp_template = templateData.preferences

      App.Utils.htmlRemoveRichtext(ui.$('[data-name=body]'), false)

    params

App.Config.set('295-WhatsappTemplateReply', WhatsappTemplateReply, 'TicketZoomArticleAction')
