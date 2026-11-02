# Outreach

A self-hosted cold email outreach tool: connect mailboxes, import leads, build multi-step
sequences, send on a schedule, and catch replies automatically.

**Stack:** Next.js 14 (App Router) · Postgres + Prisma · Redis + BullMQ · Nodemailer (SMTP) · ImapFlow (IMAP)

## What works in this version

- Sign up / log in (JWT cookie, bcrypt)
- Connect mailboxes over SMTP + IMAP (Gmail/Outlook presets, custom hosts). Connection is tested before saving; passwords are encrypted (AES-256-GCM)
- Lead lists from CSV (validation, dedupe, custom columns become `{{variables}}`)
- Campaigns with multi-step sequences, delays, `{{firstName|fallback}}` variables, `{spin|tax}` spintax
- Send window (hours, weekdays, time zone), per-mailbox daily limits, rotation across mailboxes, jitter between sends
- Follow-ups stay in the same thread and sent from the same mailbox
- Reply detection via IMAP: a reply stops that lead's sequence (auto-replies/out-of-office are ignored)
- Bounce detection (SMTP rejection + bounce emails)
- One-click unsubscribe link + `List-Unsubscribe` header; unsubscribed leads are never emailed again
- Open tracking pixel, dashboard stats, per-campaign stats, reply inbox with lead labels

## Not built yet

- "Sign in with Google / Microsoft" (OAuth). Right now Gmail needs an **App Password**; Microsoft is retiring password auth for SMTP/IMAP, so Outlook will usually need OAuth added
- Replying from the inbox (replies are read-only for now)
- Mailbox warmup network
- Lead finder / email verification, teams, billing, API/webhooks

## Run it locally

Requires Node 20+ and Docker.

```bash
npm install
cp .env.example .env        # then edit it (see below)
docker compose up -d        # Postgres + Redis
npx prisma generate
npm run db:push             # creates the tables
npm run dev                 # web app on http://localhost:3000
npm run worker              # in a second terminal: sender + reply sync
```

Both processes must be running: the web app serves the UI, the worker sends emails and reads replies.

### .env

| Variable | Notes |
|---|---|
| `DATABASE_URL`, `REDIS_URL` | Defaults match `docker-compose.yml` |
| `APP_URL` | Public URL of the web app. Used in unsubscribe and tracking links, so recipients must be able to reach it |
| `JWT_SECRET` | `openssl rand -hex 32` |
| `ENCRYPTION_KEY` | 64 hex chars: `openssl rand -hex 32`. Losing it makes saved mailbox passwords unreadable |
| `COMPANY_ADDRESS` | Postal address added to every email footer (CAN-SPAM requires one) |

### Connecting Gmail

1. Turn on 2-Step Verification on the Google account
2. Create an App Password (Google Account → Security → App passwords)
3. In **Email accounts**, pick Gmail, enter the address and the app password

## How sending works

1. Launching a campaign creates a row per lead, due immediately.
2. The worker checks every 30s for due leads and queues one send job per lead.
3. Each job re-checks the send window, picks the mailbox with the most capacity left (follow-ups reuse the original mailbox), sends, and schedules the next step.
4. Every 60s the worker reads new IMAP mail on each mailbox. Replies (matched by `In-Reply-To`/`References`) stop the sequence and appear in **Inbox**.

## Before you send real volume

- Set up SPF, DKIM and DMARC on your sending domains
- Use separate domains, not your primary one, and ramp slowly (start around 20–30 emails/day per mailbox)
- Only email people you have a lawful basis to contact, and honour unsubscribes (built in)
- Gmail/Outlook limits and policies apply; this tool does not bypass them

## Project layout

```
prisma/schema.prisma        data model
src/lib/                    auth, crypto, templating, mail, queue, schedule helpers
src/app/api/                REST routes (auth, mailboxes, leads, campaigns, tracking, unsubscribe)
src/app/(app)/              UI pages (dashboard, campaigns, leads, mailboxes, inbox)
src/worker/                 scheduler, sender, IMAP sync (run with `npm run worker`)
```

## Production notes

- Run `npm run build && npm start` for the web app and `npm run worker` as a separate long-running process
- Put the app behind HTTPS (tracking, unsubscribe and secure cookies rely on it)
- Back up Postgres and keep `ENCRYPTION_KEY` safe
