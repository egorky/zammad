# WhatsappOutboundTemplates

Zammad add-on package that extends WhatsApp Business API support with **outbound template messages**.

## Features

- Sync approved WhatsApp message templates from Meta Cloud API
- Select template and language when composing a ticket article
- Fill template variables (body, header, URL button placeholders)
- Send outbound template messages outside the 24-hour customer service window
- Works as a Zammad package without modifying Zammad core code

## Requirements

- Zammad with WhatsApp Business channel configured
- `whatsapp_sdk` gem (already included in Zammad)
- Approved templates in your Meta Business account

## Development setup

From the Zammad root directory:

```bash
bundle exec rails runner "Package.link('/workspace/packages/WhatsappOutboundTemplates')"
bundle exec rake zammad:package:migrate
bundle exec rake zammad:package:precompile
```

Restart Zammad after linking.

## Production installation

Build the package archive:

```bash
ruby packages/WhatsappOutboundTemplates/build.rb
```

Install in Zammad:

```bash
zammad run rake zammad:package:install packages/WhatsappOutboundTemplates/WhatsappOutboundTemplates-1.0.0.zpm
zammad run rake zammad:package:post_install
```

Or install via **Admin → Packages** in the web UI.

## Usage

1. Open a WhatsApp ticket.
2. Click **Send template** (article type: `WhatsApp Template`).
3. Use **Sync templates** to import templates from Meta.
4. Select template, language, and fill variables.
5. Submit the article to send the template message.

## API

- `GET /api/v1/whatsapp_message_templates?channel_id=:id`
- `POST /api/v1/whatsapp_message_templates/sync` with `{ "channel_id": :id }`

## Uninstall

```bash
zammad run rake zammad:package:uninstall WhatsappOutboundTemplates
zammad run rake zammad:package:migrate
```
