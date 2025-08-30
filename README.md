# Credit Approval App

A minimal, production-ready credit approval flow built with Phoenix LiveView. Users answer 5 eligibility questions, enter income/expenses if eligible, get an instant offer amount, then receive a PDF summary via email. The app is containerized and ships with `wkhtmltopdf` inside the image so you don’t have to install it on host machines.

---

## Table of contents

- [Features](#features)
- [Tech stack](#tech-stack)
- [Quick start (Docker)](#quick-start-docker)
- [Local setup (without Docker)](#local-setup-without-docker)
- [App flow](#app-flow)
- [Project structure](#project-structure)
- [Configuration](#configuration)
    - [Email (Swoosh)](#email-swoosh)
    - [PDF generation](#pdf-generation)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

- Multi-step flow: **Eligibility → Financials → Offer → Email** with a daisyUI stepper.
- Clear domain boundary: `CreditApp.Underwriting` (questions, scoring, decision, offer).
- PDF export via `PdfGenerator` (`wkhtmltopdf` is baked into the Docker image).
- Email delivery via Swoosh; **dev mailbox UI** for local testing (no real email required).
- Phoenix 1.8 patterns: HEEx, `<.form>` + `to_form/2`, Verified Routes `~p`.
- Tailwind CSS v4 + daisyUI; no JS required for the flow.

---

## Tech stack

- **Elixir**/**Phoenix** 1.8, **LiveView**
- **Tailwind CSS** v4, **daisyUI**
- **Swoosh** for email (+ SMTP or API adapters)
- **PdfGenerator** (wkhtmltopdf)
- **Docker** / **docker-compose** for a consistent dev runtime

---

## Quick start (Docker)

> The image installs `wkhtmltopdf`, `watchman` and fonts. No host installs required.

```bash
# 1) Build & run
docker compose up --build

# 2) App
# http://localhost:4000

# 3) Dev mailbox (preview sent emails)
# http://localhost:4000/dev/mailbox
```

---

## Local setup (without Docker)

**Prereqs:** Elixir/Erlang; `wkhtmltopdf` on PATH for PDFs.

```bash
# install deps
mix deps.get

# run the server
mix phx.server
```

You can still preview emails via the dev mailbox route `/dev/mailbox`. For real email, configure an adapter under `config/*.exs` (see [Email (Swoosh)](#email-swoosh)).

---

## App flow

1) **Eligibility**  
   Five yes/no questions, each with a point weight. The user needs **> 6 points** to proceed.

2) **Financials**  
   Fields: Monthly **income** and **expenses** in USD.  
   Offer formula: `(income - expenses) * 12` (floored at 0).

3) **Offer**  
   Shows the approved amount and asks for an email address.

4) **Email**  
   Sends a PDF summary to the provided address. In dev, check `/dev/mailbox`.

---

## Project structure

```
lib/
  credit_app/
    underwriting.ex          # domain rules: questions/0, score/1, approved?/1, offer_amount/2
    pdf.ex                   # HTML -> PDF via PdfGenerator
    notifications.ex         # Swoosh email delivery (attachments supported)
  credit_app_web/
    components/
      core_components.ex     # Phoenix CoreComponents + <.stepper> (daisyUI)
    live/
      credit_approval_live/
        index.ex             # LiveView: assigns + event handlers only
        index.html.heex      # UI template: forms + markup
    router.ex                # "/" -> CreditApprovalLive.Index, "/dev/mailbox" in dev
docker/
  Dockerfile                 # includes wkhtmltopdf, watchman and fonts
docker-compose.yml
```

- **Templates are colocated**: LiveView logic stays in `.ex`, markup in `.heex`.
- **Forms** use `<.form for={@form}>` with `to_form/2` and `field={@form[:field]}` for inputs.

---

## Configuration

### Email (Swoosh)

- **Dev**: Local preview mailbox (no external service). The route `/dev/mailbox` is enabled in dev.
- **Prod**: Choose an adapter (SMTP, SendGrid, Mailgun, SES, etc.). Example SMTP config:

```elixir
# config/runtime.exs (prod/example)
config :credit_app, CreditApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_HOST"),
  username: System.get_env("SMTP_USER"),
  password: System.get_env("SMTP_PASS"),
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  ssl: false,
  tls: :if_available,
  auth: :always
```

If you prefer API adapters (SendGrid/Mailgun/etc.), configure `Swoosh.ApiClient.Finch` and start a Finch pool in `application.ex`:
```elixir
# config/config.exs (or runtime.exs)
config :swoosh,
  api_client: Swoosh.ApiClient.Finch,
  finch_name: CreditApp.Finch

# lib/credit_app/application.ex
children = [
  CreditAppWeb.Telemetry,
  {Phoenix.PubSub, name: CreditApp.PubSub},
  {Finch, name: CreditApp.Finch},    # needed for API adapters
  CreditAppWeb.Endpoint
]
```

### PDF generation

- Implemented via `PdfGenerator.generate/2` (wkhtmltopdf backend).
- In Docker, wkhtmltopdf + fonts are preinstalled.
- On bare metal, install `wkhtmltopdf` or configure an alternative engine per library docs.

---

## Troubleshooting

- **Tailwind: `watchman: not found`**  
  Informational only; CSS still builds. Add `watchman` to the Dockerfile to silence it.

- **PDF generation fails on host**  
  Ensure `wkhtmltopdf` is installed or run via Docker.

- **`CoreComponents.input/1` KeyError `:value`**  
  Use `<.form for={@form}>` with `field={@form[:field]}` or pass both `name` and `value` when not using a form.

- **Dev mailbox not visible**  
  Confirm `dev_routes: true` and the `/dev/mailbox` forward exists in `router.ex` under the dev block.

---

## License

MIT