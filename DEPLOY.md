# Deploying Outreach to a public website

You need two always-on processes (the **web app** and the **worker**), plus **Postgres** and **Redis**.
Pick one path below. Path A is quickest; Path B is cheapest and gives you the most control.

> **Check SMTP before you commit to a host.** Sending needs outbound SMTP (465 or 587) and IMAP (993).
> Some hosts block these ports, especially on free or new accounts. If connecting a mailbox times out
> after deploy, that is the cause. Try Gmail on port **587** (choose "Other (custom)" when connecting
> and set SMTP port 587), or switch hosts.

---

## Path A: Railway (about 10 minutes)

Menu names may differ slightly as Railway changes its UI.

1. **Put the code on GitHub.** Create a private repo and push this folder to it.
2. **Create a project** on railway.com → *New Project* → *Deploy from GitHub repo* → pick your repo. This becomes your **web** service.
3. **Add databases** in the same project: *New* → *Database* → **PostgreSQL**, then again for **Redis**.
4. **Web service variables** (Service → Variables):

   | Variable | Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` |
   | `REDIS_URL` | `${{Redis.REDIS_URL}}` |
   | `JWT_SECRET` | output of `openssl rand -hex 32` |
   | `ENCRYPTION_KEY` | output of `openssl rand -hex 32` (keep a copy somewhere safe) |
   | `COMPANY_ADDRESS` | your postal address |
   | `APP_URL` | set in step 6 |

   If your Postgres/Redis services are named differently, change the names inside `${{ }}`.
5. **Generate a public URL** for the web service: Settings → Networking → *Generate Domain*.
6. **Set `APP_URL`** to that URL, for example `https://outreach-production.up.railway.app` (no trailing slash). Redeploy.
7. **Add the worker:** *New* → *GitHub Repo* → the same repo. In this second service:
   - Settings → Deploy → **Custom Start Command**: `npm run worker:prod`
   - Copy the same variables as the web service (all six, including `APP_URL`)
   - Do **not** give it a public domain
8. Open your URL, register an account, and follow the steps in the README (Email accounts → Leads → Campaigns).

The web service creates the database tables automatically on every start (`prisma db push`).

---

## Path B: One VPS with Docker Compose (about 20 minutes)

1. **Get a server:** Ubuntu 22.04+ with 1 GB+ RAM (Hetzner, DigitalOcean, etc.) and a **domain** you control.
2. **DNS:** create an `A` record, e.g. `outreach.example.com`, pointing to the server's IP.
3. **Install Docker** on the server: https://docs.docker.com/engine/install/ubuntu/
4. **Copy the project** to the server (`git clone` your repo, or `scp -r`).
5. **Configure:**
   ```bash
   cp .env.prod.example .env.prod
   # edit .env.prod: DOMAIN, POSTGRES_PASSWORD, JWT_SECRET, ENCRYPTION_KEY, COMPANY_ADDRESS
   # generate secrets with: openssl rand -hex 32
   ```
6. **Open ports 80 and 443** in the server firewall.
7. **Start everything:**
   ```bash
   docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
   ```
   Caddy fetches an HTTPS certificate automatically (it can take a minute after DNS resolves).
8. Visit `https://your-domain`, register, and start.

Useful commands:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f web worker   # watch logs
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build        # deploy an update
```

---

## After it is live

- **Test with your own addresses first.** Create a lead list of 2–3 addresses you own, run a small campaign, reply from one of them, and confirm the sequence stops and the reply shows in Inbox.
- **Registration is open.** Anyone who finds the URL can create an account. For a private test, share the URL only with people you trust, or take the app down when you are not using it.
- **Protect `ENCRYPTION_KEY`.** If you lose or change it, saved mailbox passwords become unreadable and mailboxes must be reconnected.
- **Back up Postgres** (`pg_dump`) before relying on it.
- **Sending reputation:** set up SPF, DKIM and DMARC on your sending domains and start at about 20–30 emails per day per mailbox.
