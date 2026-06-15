# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME = 'whatsapp template message'

class WhatsappTemplateReply
  @isWhatsappTicket: (ticket) ->
    return false if !ticket?.preferences?.whatsapp
    return false if !ticket?.create_article_type_id

    articleTypeCreate = App.TicketArticleType.find(ticket.create_article_type_id)?.name
    articleTypeCreate is 'whatsapp message'

  @isCustomerWhatsappMessage: (article) ->
    return false if !article?.type?.name
    return false if article.type.name isnt 'whatsapp message'

    sender = App.TicketArticleSender.find(article.sender_id)
    sender?.name is 'Customer'

  @canUseWhatsapp: (ticket) ->
    alert = new App.TicketZoomChannel(ticket).channelAlert()
    alert?.type && alert.type != 'danger'

  @ensureWhatsappReplyAction: (actions, ticket, article) ->
    return actions if !@isCustomerWhatsappMessage(article)
    return actions if !@canUseWhatsapp(ticket)
    return actions if _.find(actions, (entry) -> entry.type is 'whatsappReply')

    actions.push {
      name: __('reply')
      type: 'whatsappReply'
      icon: 'reply'
      href: '#'
    }

    actions

  @action: (actions, ticket, article, ui) ->
    return actions if !ticket.editable()
    return actions if ticket.currentView() is 'customer'
    return actions if !@isWhatsappTicket(ticket)

    actions = @ensureWhatsappReplyAction(actions, ticket, article)

    return actions if _.find(actions, (entry) -> entry.type is 'whatsappTemplateReply')

    actions.push {
      name: __('Send template')
      type: 'whatsappTemplateReply'
      icon: 'document'
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
      icon:       'document'
      attributes: []
      internal:   false
      features:   []
    }

    articleTypes

  @params: (type, params, ui) ->
    if type is WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME or params.preferences?.whatsapp_template
      articleType = App.TicketArticleType.findByAttribute('name', WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME)
      sender = App.TicketArticleSender.findByAttribute('name', 'Agent')

      if articleType
        params.type_id = articleType.id
        params.type = WHATSAPP_TEMPLATE_ARTICLE_TYPE_NAME
      if sender
        params.sender_id = sender.id

      templateData = ui.whatsappTemplateFormData?()
      if templateData
        params.content_type = 'text/plain'
        params.body = templateData.preview || ''
        params.preferences ||= {}
        params.preferences.whatsapp_template = templateData.preferences

      App.Utils.htmlRemoveRichtext(ui.$('[data-name=body]'), false)

    params

App.Config.set('310-WhatsappTemplateReply', WhatsappTemplateReply, 'TicketZoomArticleAction')
