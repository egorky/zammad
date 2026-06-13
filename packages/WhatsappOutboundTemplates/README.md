# WhatsappOutboundTemplates

Zammad add-on package that extends WhatsApp Business API support with **outbound template messages**.

## Features

- **Sync templates** button in Admin → Channels → WhatsApp (per account)
- **WhatsApp template** ticket create type for proactive outbound conversations
- Template selector with language and variables on ticket create and ticket reply
- Delivery via dedicated article type `whatsapp template message`

## Requirements

- Zammad with at least one active WhatsApp Business channel
- Approved templates in your Meta Business account
- Customer **mobile** phone number for outbound ticket creation

## Installation

### First install

```bash
ruby packages/WhatsappOutboundTemplates/build.rb
zammad run rake zammad:package:install /ruta/absoluta/WhatsappOutboundTemplates-1.0.8.zpm
zammad run rake zammad:package:post_install
zammad restart
```

`zammad:package:post_install` is **required** for frontend changes. It runs migrations and rebuilds the Vue frontend assets.

### Upgrade from 1.0.0 through 1.0.6

```bash
ruby packages/WhatsappOutboundTemplates/build.rb
zammad run rake zammad:package:install /ruta/absoluta/WhatsappOutboundTemplates-1.0.8.zpm
zammad run rake zammad:package:post_install
zammad restart
```

### Development (symlink)

```bash
bundle exec rails runner "Package.link('/path/to/zammad/packages/WhatsappOutboundTemplates')"
bundle exec rake zammad:package:migrate
bundle exec rake zammad:package:precompile
```

Restart the application afterwards.

## Usage

### Sync templates (admin)

1. Go to **Admin → Channels → WhatsApp**
2. Click **Sync Templates** on the desired account
3. Templates are stored in Zammad and available in ticket forms

### Create outbound WhatsApp ticket

1. Create a new ticket for a customer with a **mobile** number
2. Select group linked to a WhatsApp channel
3. Choose article type **WhatsApp template**
4. Select template, language, and fill variables
5. Create the ticket — the template message is sent automatically

### Reply on existing WhatsApp ticket

1. Open a WhatsApp ticket
2. Click **Send template** on any article (or select **WhatsApp Template** in the article channel selector)
3. Choose template, language, and variables
4. Submit the article

## Troubleshooting

| Symptom | Solution |
|---------|----------|
| No UI changes after install | Run `zammad:package:post_install` and restart Zammad |
| No WhatsApp option on ticket create | Ensure migration ran; check **Admin → System → API → Ticket Create** settings include "WhatsApp template outbound" |
| Templates list empty | Click **Sync Templates** in WhatsApp channel settings first |
| Build fails on post_install with `ArticleReplyPanel.vue` | Upgrade to 1.0.2+ (1.0.0/1.0.1 replaced core Vue files incorrectly) |
| No Sync Templates button / ticket create tabs broken | Upgrade to 1.0.3+ and run `post_install` (legacy UI patches moved to `app_post`) |
| Ticket create error `Cannot read properties of undefined (reading 'sender')` | Upgrade to 1.0.3+ — migration added `whatsapp-template-out` without legacy UI mapping |
| API 422 on `whatsapp_message_templates?group_id=` | Upgrade to 1.0.6+ — returns `[]` when group has no WhatsApp channel; pick the correct group |
| Sync button shows no message | Upgrade to 1.0.6+ — fixed POST `channel_id` parameter handling |
| `uninitialized constant EnsureTicketCreateTypes` on migrate | Upgrade to 1.0.7+ — fixes migration class name |
| Ticket create shows only WhatsApp template | Upgrade to 1.0.6+ — migration restores phone/email create types alongside WhatsApp |
| Outbound create fails | Customer must have **mobile** filled; group must have an active WhatsApp channel |
| Templates empty after sync | Select the ticket group linked to your WhatsApp channel (not necessarily group ID 1) |
| Template selector not visible on ticket create | Upgrade to 1.0.8+ — fixes legacy UI body field selector (`data-name=body`) |
| Sync Templates button does nothing | Upgrade to 1.0.8+ — fixes click handler binding after channel list render |

## API

- `GET /api/v1/whatsapp_message_templates?channel_id=:id`
- `GET /api/v1/whatsapp_message_templates?group_id=:id`
- `POST /api/v1/whatsapp_message_templates/sync` with `{ "channel_id": :id }` or `{ "group_id": :id }`
