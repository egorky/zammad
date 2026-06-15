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
zammad run rake zammad:package:install /ruta/absoluta/WhatsappOutboundTemplates-1.0.26.zpm
zammad run rake zammad:package:post_install
zammad restart
```

`zammad:package:post_install` is **required** for frontend changes. It runs migrations and rebuilds the Vue frontend assets.

### Upgrade from 1.0.0 through 1.0.6

```bash
ruby packages/WhatsappOutboundTemplates/build.rb
zammad run rake zammad:package:install /ruta/absoluta/WhatsappOutboundTemplates-1.0.26.zpm
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

### View templates (admin)

1. Go to **Admin → Channels → WhatsApp**
2. Click **View Templates** on the desired account
3. Browse synchronized templates in a structured gallery (header, body, footer, buttons)
4. Open a template for a Meta-style preview and component details
5. Use **Back to accounts** to return to the WhatsApp channel list

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
2. On a **customer WhatsApp message** within the 24h window, use **reply** for free text or **Send template** for an approved template
3. Outside the 24h window, only **Send template** is available (via the article action or **WhatsApp Template** article type)

| No Send template button on open WhatsApp tickets | Upgrade to 1.0.20+ — legacy ticket zoom UI support for template reply |
| Reply replaced by Send template within 24h window | Upgrade to 1.0.21+ — restores reply alongside Send template on customer messages |

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
| Sync shows no feedback / templates not listed in ticket create | Upgrade to 1.0.9+ — sync modal with results; templates loaded via API (not client Channel cache) |
| `relation "message_templates" does not exist` | Upgrade to 1.0.10+ — fixes model table name (`whatsapp_message_templates`) |
| Sync button still does nothing / no POST in logs | Upgrade to 1.0.11+ — global click handler via `App.Ajax.request` + toast and modal |
| Multiple WhatsApp accounts | Upgrade to 1.0.11+ — account selector on ticket create when more than one channel exists |
| Sync fails with `undefined method 'data' for PaginationRecords` | Upgrade to 1.0.12+ — compatible with whatsapp_sdk 1.1.0 (`records` + pagination) |
| Sync fails with `wrong number of arguments (given 2, expected 1)` | Upgrade to 1.0.13+ — fixes `__()` interpolation in sync success message |
| Title/Text fields shown on WhatsApp template ticket create | Upgrade to 1.0.14+ — hides title/body, shows template preview and variable fields only |
| View synced templates in WhatsApp admin | Upgrade to 1.0.14+ — **View Templates** button per account |
| Template not sent / job fails with `undefined method 'execute' for Deliver` | Upgrade to 1.0.17+ — delivery runs via nested `CommunicateWhatsappTemplateJob::Deliver` |
| Template not sent: `Can't find ticket.preferences['channel_id']` | Upgrade to 1.0.18+ — legacy REST ticket create now sets WhatsApp ticket preferences |
| Title/Text fields reappear after changing group | Upgrade to 1.0.15+ — re-applies layout after core workflow |
| New ticket created while WhatsApp conversation is open | Upgrade to 1.0.19+ — reuses open WhatsApp ticket via REST and sets `create_article_type` to `whatsapp message` |
| Send template icon invisible on light ticket background | Upgrade to 1.0.22+ — uses `document` icon in legacy UI and `snippet` in Vue |
| Template article saved but never delivered on existing ticket (PUT update) | Upgrade to 1.0.23+ — server fixes type/enqueue; 1.0.24+ also sends `type_id` on ticket zoom submit |
| View Templates opens plain text modal | Upgrade to 1.0.25+ — structured template gallery with Meta-style preview and back navigation |
| No sent/delivered/read indicators on WhatsApp articles | Upgrade to 1.0.25+ — delivery status at bottom of message bubbles; failure alerts when delivery fails |
| Vue desktop UI broken after 1.0.25 (`desktop.ts` not in manifest) | Upgrade to 1.0.26+ — removes core `ArticleBubble.vue` override that broke Vite build; run `post_install` |
| Legacy template viewer or delivery checks not visible after upgrade | Upgrade to 1.0.26+ and run `zammad:package:post_install` (rebuilds CoffeeScript + Vite assets) |

## API

- `GET /api/v1/whatsapp_message_templates?channel_id=:id`
- `GET /api/v1/whatsapp_message_templates?group_id=:id`
- `GET /api/v1/whatsapp_message_templates/channel_groups`
- `POST /api/v1/whatsapp_message_templates/sync` with `{ "channel_id": :id }` or `{ "group_id": :id }`
