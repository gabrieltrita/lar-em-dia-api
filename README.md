# laremdia-api

API (Rails 8.1, API-only) for **Lar em Dia**, a family budgeting and cash-flow projection app, forked from [trita-api](https://github.com/gabrieltrita/trita-api). The front end lives in the separate **lar-em-dia-app** project (Flutter: web, Android and iOS).

## Stack

| Service | Purpose | Default URL |
|---|---|---|
| **api** | Rails 8.1 / Puma | http://localhost:3000 |
| **sidekiq** | Background jobs and scheduled jobs (sidekiq-cron) | dashboard at http://localhost:3000/sidekiq |
| **db** | PostgreSQL 17 | localhost:5432 |
| **redis** | Cache, Sidekiq queues, JWT denylist, rate limiting | localhost:6379 |
| **mailhog** | Captures every email sent in development | http://localhost:8025 |
| **adminer** | Web UI for Postgres | http://localhost:8080 |

Every port is published on `127.0.0.1` only. Redis requires a password.

Main gems: `jwt`, `bcrypt`, `rotp` (2FA), `pundit`, `rack-cors`, `rack-attack`, `sidekiq` + `sidekiq-cron`, `pagy`, `blueprinter`, `sentry-rails`, `rspec-rails`.

## Getting started

```bash
cp .env.example .env
```

Replace every `troque-me` value in `.env`:

```bash
bin/rails db:encryption:init                          # AR_ENCRYPTION_* values
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'          # JWT_SECRET
ruby -rsecurerandom -e 'puts SecureRandom.alphanumeric(32)' # REDIS_PASSWORD, DATABASE_PASSWORD, SIDEKIQ_WEB_PASSWORD
```

`REDIS_PASSWORD` must also be inside `REDIS_URL` and `SIDEKIQ_REDIS_URL` (`redis://:<password>@localhost:6379/1`).

```bash
docker compose up -d --build
docker compose exec api bin/rails db:seed
```

The seed creates a confirmed admin (`ADMIN_EMAIL`, default `admin@<domain>`, / `ADMIN_PASSWORD`) and, in development, `user@<domain>` / `User@123456`, where `<domain>` comes from `config/app.yml`. The admin must enable 2FA (see below) before using the admin endpoints.

If a port is already taken, change `API_PORT`, `DB_PORT`, `REDIS_PORT`, `MAILHOG_SMTP_PORT`, `MAILHOG_WEB_PORT` or `ADMINER_PORT` in `.env`. Use `BIND_ADDRESS=0.0.0.0` only to reach the API from another device on your network.

### Useful commands

```bash
docker compose logs -f api sidekiq
docker compose exec api bin/rails console
docker compose exec api bundle exec rspec
docker compose exec api bin/rails g api_resource Product name:string price:decimal
```

To run Rails on the host while using the containers for services: `docker compose up -d db redis mailhog`, then `bin/rails s` (`.env` points to `localhost`).

### Quality

```bash
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
```

GitHub Actions runs all four on every pull request.

`bundle exec rspec` enforces **100% line and branch coverage** with SimpleCov (`.simplecov`) and fails below it, locally and in CI. The HTML report is written to `coverage/index.html`; in CI it is attached to the run as the `coverage` artifact. Keep it at 100% by testing new code, not by lowering the threshold or excluding files; remove dead code instead.

Request specs also enforce the API contract with `openapi_first` (`spec/support/openapi.rb`): every response under `/api/v1` is validated against `docs/openapi.yaml` (documented status and body schema), and the suite fails unless **100% of the documented responses** are exercised by some spec. Undocumented 401, 404 and 500 responses are tolerated on every route. The API coverage report is written to `coverage/openapi_coverage.html`. Documenting a new status therefore needs a spec that triggers it, and changing a response needs the matching schema change.

## Documentation

- **OpenAPI / Swagger UI**: http://localhost:3000/docs (source: [`docs/openapi.yaml`](docs/openapi.yaml)). A spec fails if any route is undocumented.
- **Security model, key rotation and incident response**: [`docs/SECURITY.md`](docs/SECURITY.md).

## Response format

```json
{ "data": { }, "meta": { } }
{ "error": { "code": "validation_failed", "message": "Invalid data", "details": { "password": [ { "code": "too_short", "message": "Password is too short (minimum is 8 characters)" } ] } } }
```

Every message is in English. Clients translate using `error.code` and `details[field][].code`, never the message text. The full list of codes is in the OpenAPI description.

## Project layout

```
app/
  blueprints/        JSON serializers
  controllers/
    concerns/        Authenticatable, TokenResponder, ErrorHandling, Paginatable
    api/v1/auth/     register, confirm, login, two_factor, refresh, logout, passwords
    api/v1/me/       sessions, two_factor, consents, identities
    api/v1/admin/    users, audit_logs
    api/v1/          categories, balances, entries (Lar em Dia)
  jobs/              MaintenanceCleanupJob, DueAlertsJob
  mailers/           UserMailer
  models/            User, RefreshToken, AuditLog, Consent, Identity, Current, Category, Balance, Entry
  policies/          Pundit
  services/auth/     JsonWebToken, TokenIssuer, RefreshTokenRotator, TokenDenylist, TwoFactorChallenge
bin/rename           renames the app after forking (see App identity)
lib/                 EnvValidator, AppRenamer, generators/api_resource, rake tasks
config/app.yml       app identity (name, slug, domain)
config/routes/app.rb the app's own routes (drawn inside /api/v1; the base never edits it)
config/schedule.yml  sidekiq-cron schedule
docs/                openapi.yaml, SECURITY.md, FORKING.md
spec/                RSpec
```

## App identity

`config/app.yml` is the single source of the app's identity; a fork changes these three values:

| Key | Example | Drives |
|---|---|---|
| `name` | `Lar em Dia` | Email subjects, default sender name, the 2FA account label in authenticator apps |
| `slug` | `laremdia` | JWT issuer (`laremdia-api`), refresh cookie (`laremdia_refresh`), database names (`laremdia_api_development`), Redis cache namespace, data export file name, Swagger page title |
| `domain` | `laremdia.dev` | Default sender `no-reply@<domain>` and the seed users' emails |

`slug` must start with a letter and contain only lowercase letters and digits, because it becomes part of database, cookie, container and image names. Code reads the values through `Rails.configuration.x.app`.

To rename the app after forking, run `bin/rename SLUG [--name NAME] [--domain DOMAIN]` (for example `bin/rename acme`, or `bin/rename minhaloja --name "Minha Loja" --domain minhaloja.com.br`). It rewrites `config/app.yml`, the `LaremdiaApi` module, the Compose project and image names and every mention in `README.md`, `docs/` and `.claude/CLAUDE.md`, validates everything before writing, and prints the manual steps that remain (new secrets, security contact, git remotes, databases). Name defaults to the capitalized slug and domain to `SLUG.dev`.

Starting a new app from this base: follow [docs/FORKING.md](docs/FORKING.md) (repository and `upstream` remote, rename, secrets, first boot, where to put domain code, pulling fixes from the base).

## Production

`Dockerfile` (multi-stage, non-root) is for production; `Dockerfile.dev` is used by docker-compose.

The app refuses to boot in production unless these are set and strong enough: `DATABASE_URL`, `REDIS_URL`, `SIDEKIQ_REDIS_URL`, `SECRET_KEY_BASE` (64+, `bin/rails secret`), `JWT_SECRET` (64+), `AR_ENCRYPTION_*` (32+), `APP_HOSTS`, `CORS_ORIGINS` (https only), `FRONTEND_URL`, `MAILER_FROM`, `SMTP_ADDRESS`, `SIDEKIQ_WEB_USERNAME`, `SIDEKIQ_WEB_PASSWORD` (16+). Optional: `SENTRY_DSN`, `JWT_SECRET_PREVIOUS`, `ENABLE_API_DOCS`, `TERMS_VERSION`, `PRIVACY_VERSION`, `GOOGLE_CLIENT_IDS` (comma-separated Google OAuth client ids: web, iOS, Android; empty disables Google login), `APPLE_CLIENT_IDS` (comma-separated Apple identifiers: the app's bundle id and the web Services ID; empty disables Apple login), `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` (the Sign in with Apple key: team id, key id and the contents of the `.p8` file with `\n` instead of line breaks; all three or none, used to revoke the Apple token when an account is deleted).

Logs go to stdout as one JSON object per line. Each request is a single line (lograge) with `time`, `level`, `method`, `path`, `controller`, `action`, `status`, `duration`, `db`, `view`, `request_id`, `user_id` and, on errors, the exception class:

```json
{"time":"2026-10-23T16:50:34.216Z","level":"INFO","method":"POST","path":"/api/v1/me","controller":"Api::V1::MeController","action":"update","status":200,"duration":59.98,"db":8.37,"view":0.13,"request_id":"263d77c3-…","user_id":"2ef8b383-…"}
```

Other lines carry `message` (or `error` with the exception class). Request parameters, bodies, IPs, user agents, exception messages and job arguments are never logged; `request_id` links a line to the audit log and to Sentry. `/up` is not logged. Sidekiq logs JSON too, with its own keys (`ts`, `lvl`, `msg`, `ctx` with the job class, id and duration). Set `RAILS_LOG_LEVEL` to change the level (default `info`).

In development logs stay human-readable; set `LOG_FORMAT=json` to see the production format.

Two health endpoints, both public and outside `/api/v1`:

| Endpoint | Meaning | Use it for |
|---|---|---|
| `GET /up` | The Rails process is running (liveness) | Container healthchecks and restarts (docker-compose uses it) |
| `GET /health` | The app can serve requests (readiness): Postgres, Redis cache and Sidekiq | Load balancers, uptime monitors, deploy checks |

`/health` answers `{"status":"ok","checks":{"database":"ok","cache":"ok","sidekiq":"ok"}}`. A failing database or cache makes it `down` with **503**; Sidekiq without processes, or a queue waiting more than 5 minutes, makes it `degraded` with **200**, because the API still serves requests and only background work is delayed. It never returns error details, is throttled to 60 requests per minute per IP, is allowed for any `Host` and is not logged.

---

### Deploying with Kamal

`config/deploy.yml` runs the API (`web`) and Sidekiq (`job`) behind kamal-proxy with automatic TLS, plus Postgres 17 and Redis 7 as accessories on the same server, with no published ports. The app name comes from `config/app.yml`; everything specific to your server comes from the environment of the machine that runs `bin/kamal`, never from the repository.

Before the first deploy: an Ubuntu server reachable by SSH key with ports 80 and 443 open, a DNS A record for the API host, and a GitHub token with `write:packages` (images go to `ghcr.io`).

Variables to export (shell or password manager; `.kamal/secrets` only holds references to them, never write a value in it): `DEPLOY_HOST`, `DEPLOY_SSH_USER` (default `root`), `DEPLOY_ARCH` (default `amd64`), `APP_HOST`, `KAMAL_REGISTRY_USERNAME`, `KAMAL_REGISTRY_PASSWORD`, `CORS_ORIGINS`, `FRONTEND_URL`, `MAILER_FROM`, `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, every secret listed in the production section above, `POSTGRES_PASSWORD` and `REDIS_PASSWORD`, plus the optional ones (`SENTRY_DSN`, `GOOGLE_CLIENT_IDS`, `APPLE_*`). The connection strings carry the passwords, so you build them:

- `DATABASE_URL`: `postgres://postgres:<POSTGRES_PASSWORD>@<slug>-api-db:5432/<slug>_api_production`
- `REDIS_URL`: `redis://:<REDIS_PASSWORD>@<slug>-api-redis:6379/1`
- `SIDEKIQ_REDIS_URL`: the same with `/0`

Commands: `bin/kamal setup` the first time (installs Docker, boots the accessories, the proxy and the app), `bin/kamal deploy` afterwards, `bin/kamal rollback VERSION`, and the aliases `bin/kamal console`, `shell`, `logs` and `dbc`. The web container runs `db:prepare` on start, so migrations apply on every deploy.

Changing `SECRET_KEY_BASE` invalidates every user's 2FA backup codes. Database backups arrive with phase 4.4; until then take `pg_dump` by hand.

### Staging with Kamal

`bin/kamal setup -d staging` and `bin/kamal deploy -d staging` use `config/deploy.staging.yml` on top of `config/deploy.yml`: service `<slug>-api-staging` with its own Postgres and Redis containers, database `<slug>_api_staging`, and `ENABLE_API_DOCS=true`, so Swagger is at `/docs`. Staging can share the server with production or use another one, because `DEPLOY_HOST` comes from your environment.

`.kamal/secrets.staging` reads every secret from a variable with the `STAGING_` prefix (`STAGING_JWT_SECRET`, `STAGING_DATABASE_URL`, `STAGING_POSTGRES_PASSWORD`, ...), so production and staging secrets can live side by side and one can never be used for the other by mistake; only `KAMAL_REGISTRY_PASSWORD` is shared. The variables that are not secrets keep their names (`DEPLOY_HOST`, `APP_HOST`, `CORS_ORIGINS`, `FRONTEND_URL`, ...): export the staging values before the command.

- `STAGING_DATABASE_URL`: `postgres://postgres:<STAGING_POSTGRES_PASSWORD>@<slug>-api-staging-db:5432/<slug>_api_staging`
- `STAGING_REDIS_URL`: `redis://:<STAGING_REDIS_PASSWORD>@<slug>-api-staging-redis:6379/1`, and `STAGING_SIDEKIQ_REDIS_URL` the same with `/0`
- Point `SMTP_ADDRESS` at a test mailbox so staging never emails real users.

Kamal does not warn about a secret that was not exported: it reaches the container empty, `EnvValidator` refuses to boot, the health check fails and the deploy stops with the previous version still running.

### Continuous deployment

`.github/workflows/deploy.yml` runs the CI and then deploys: a push to `main` goes to **staging**, and a version tag (`0.3.0`, no `v`) goes to **production**, only if the tagged commit is on `main`. Production has no other gate, so creating the tag is the approval. A job is skipped when its server is not configured (`DEPLOY_HOST` for production, `STAGING_DEPLOY_HOST` for staging). Images are pushed to `ghcr.io` with the workflow token, so no registry token is stored; if the package was first created with a personal token, give this repository access to it in the package settings.

The first setup of each environment also runs from GitHub: Actions, Deploy, Run workflow on `main`, choosing `staging` or `production`. That run connects with the same deploy key, prepares the server with `.github/actions/kamal-deploy/prepare-server.sh` (installs Docker when it is missing, adds the deploy user to the `docker` group and opens ports 80 and 443 in iptables, saving the rules when `netfilter-persistent` is there, as on Oracle Cloud images) and then runs `bin/kamal setup` instead of `bin/kamal deploy`. It is safe to run again. Pushes and tags keep running `bin/kamal deploy`. When `DEPLOY_ARCH` is `arm64` (Ampere, Graviton), the action sets up QEMU so the amd64 runner can build the image; the first build takes a while, later ones reuse the cache. `bin/kamal setup` from your machine still works the same way.

Repository variables (Settings, Secrets and variables, Actions): `DEPLOY_HOST`, `DEPLOY_SSH_USER`, `APP_HOST`, `CORS_ORIGINS`, `FRONTEND_URL`, `MAILER_FROM`, `SMTP_ADDRESS` and the optional `DEPLOY_ARCH`, `SMTP_PORT`, `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_IDS`. Staging uses the same names with the `STAGING_` prefix.

Repository secrets: the ones listed under "Deploying with Kamal" (production, plain names), the same with the `STAGING_` prefix for staging, and for each environment `DEPLOY_SSH_PRIVATE_KEY` and `DEPLOY_SSH_KNOWN_HOSTS` (`STAGING_DEPLOY_SSH_PRIVATE_KEY`, `STAGING_DEPLOY_SSH_KNOWN_HOSTS`).

`bin/deploy-secrets staging|production HOST [--repo OWNER/NAME]` fills the repository secrets that need no outside account, through the GitHub CLI (`gh auth login` first), and never prints a value: `SECRET_KEY_BASE`, `JWT_SECRET`, the three `AR_ENCRYPTION_*` keys, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `DATABASE_URL`, `REDIS_URL` and `SIDEKIQ_REDIS_URL` built with those passwords, `SIDEKIQ_WEB_USERNAME` (`sidekiq`) and `SIDEKIQ_WEB_PASSWORD`, plus a new ed25519 deploy key (`DEPLOY_SSH_PRIVATE_KEY`) and the server's host key (`DEPLOY_SSH_KNOWN_HOSTS`, from `ssh-keyscan`), all with the `STAGING_` prefix for staging. It prints the public key to append to `~/.ssh/authorized_keys` of the deploy user, the host key fingerprint to compare with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the server, and the secrets left to you (`SMTP_USERNAME`, `SMTP_PASSWORD`, and the optional `SENTRY_DSN` and `APPLE_*`). It refuses to replace secrets that already exist unless you pass `--force`, because new encryption keys make an existing database unreadable. It needs only Ruby, OpenSSH and `gh`, so it runs in a GitHub Codespace when you are away from your machine.

Deploy user on the server (once per server), if you do not use the image's default sudo user (`ubuntu` on Oracle Cloud and AWS, which the setup run adds to the `docker` group itself):

```bash
adduser --disabled-password --gecos "" deploy
usermod -aG docker deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
```

By hand instead of `bin/deploy-secrets`: `ssh-keygen -t ed25519 -N "" -C ci-deploy -f deploy_key`, append `deploy_key.pub` to `/home/deploy/.ssh/authorized_keys`, run `ssh-keyscan -t ed25519 <host> > known_hosts` and check its fingerprint against `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the server, then `gh secret set DEPLOY_SSH_PRIVATE_KEY < deploy_key` and `gh secret set DEPLOY_SSH_KNOWN_HOSTS < known_hosts` (and delete the local files). Set `DEPLOY_SSH_USER` to `deploy`. Members of the `docker` group are root-equivalent on that server, so use a key that is only for this.

Releasing: promote `dev` with a `release/YYYY-MM-DD` branch and a PR to `main`; the merge deploys staging; when staging looks right, `git tag 0.3.0 origin/main && git push origin 0.3.0` deploys production. Database backups arrive with phase 4.4.

## Features and how to use them

All paths below are relative to `/api/v1`. Authenticated calls send `Authorization: Bearer <access_token>`.

### 1. Sign-up with email confirmation

```http
POST /auth/register
{ "email": "ana@example.com", "password": "Secret@123", "password_confirmation": "Secret@123",
  "first_name": "Ana", "last_name": "Silva", "phone": "+5511999990000",
  "accept_terms": true, "accept_privacy": true, "accept_marketing": false }
```

- Always answers `202` when the payload is valid, whether or not the email exists, so accounts cannot be enumerated.
- The email owner receives a confirmation link `FRONTEND_URL/confirm-email?token=...` (or a "sign-up attempt" notice if the account already exists).
- Accepting `terms` and `privacy` is mandatory and stored as consent history.
- The front end reads the token from the URL and calls:

```http
POST /auth/confirm        { "token": "..." }   -> 200 with user + tokens (signed in)
POST /auth/confirm/resend { "email": "..." }   -> always 202
```

Unconfirmed sign-ups are deleted after 7 days.

### 2. Login, tokens and refresh

```http
POST /auth/login { "email": "ana@example.com", "password": "Secret@123" }
```

```json
{ "data": { "user": { }, "tokens": { "token_type": "Bearer", "access_token": "eyJ...", "expires_in": 900,
  "expires_at": "...", "refresh_token": "..." }, "two_factor_setup_required": false } }
```

- `access_token` lasts 15 minutes. On a `401`, call refresh once and retry the request.
- `refresh_token` lasts 30 days and is replaced on every refresh. Reusing an old one revokes every session (`refresh_token_reused`).
- An unconfirmed email returns `403 email_not_confirmed` (only after the right password).

```http
POST /auth/refresh { "refresh_token": "..." }
```

### 3. Cookie mode for browsers (recommended for the Flutter web build)

Send `X-Token-Transport: cookie` on login, two_factor, confirm, refresh and `PATCH /me/password`, with `credentials: "include"`:

```js
await fetch(`${API}/auth/login`, {
  method: "POST",
  credentials: "include",
  headers: { "Content-Type": "application/json", "X-Token-Transport": "cookie" },
  body: JSON.stringify({ email, password }),
});
await fetch(`${API}/auth/refresh`, { method: "POST", credentials: "include", headers: { "X-Token-Transport": "cookie" } });
```

The refresh token goes into an `httpOnly`, `SameSite=Strict` cookie that JavaScript cannot read, and is removed from the JSON. Keep the access token in memory only. Without the header the cookie is ignored (CSRF protection).

The Android and iOS builds of lar-em-dia-app use the default body mode instead and keep the refresh token in the platform keystore (`flutter_secure_storage`).

### 4. Two-factor authentication (TOTP)

Enable it:

```http
POST /me/two_factor/setup  { "current_password": "..." }  -> { "secret", "provisioning_uri" }
POST /me/two_factor/enable { "code": "123456" }           -> { "backup_codes": [10 codes] }
```

Render `provisioning_uri` as a QR code for Google Authenticator, 1Password, Authy, etc. Show the backup codes only once.

Log in with 2FA:

```http
POST /auth/login      -> { "two_factor_required": true, "challenge_token": "...", "expires_in": 300 }
POST /auth/two_factor { "challenge_token": "...", "code": "123456" }   -> user + tokens
```

`code` also accepts a backup code (single use). Other endpoints: `GET /me/two_factor`, `POST /me/two_factor/backup_codes`, `DELETE /me/two_factor` (password + code; not allowed for admins).

**2FA is mandatory for admins**: admin endpoints return `403 two_factor_setup_required` until it is enabled, and the login response carries `two_factor_setup_required: true`.

### 5. Logout and sessions per device

```http
DELETE /auth/logout                          -> ends this session immediately
DELETE /auth/logout { "all_devices": true }  -> ends every session
GET    /me/sessions                          -> [{ id, current, user_agent, ip_address, started_at, last_activity_at }]
DELETE /me/sessions/:id                      -> ends that device immediately
```

Revoked access tokens stop working at once (Redis denylist), not only when they expire.

### 6. Password recovery and change

```http
POST  /auth/password/forgot { "email": "..." }                                -> always 202
POST  /auth/password/reset  { "token": "...", "password": "...", "password_confirmation": "..." }
PATCH /me/password          { "current_password": "...", "password": "...", "password_confirmation": "..." }
```

- The reset link (`FRONTEND_URL/reset-password?token=...`) lasts 30 minutes and works once.
- Any password change (reset, user or admin) revokes every session, unlocks the account and emails the owner.
- `PATCH /me/password` returns a fresh session.

Passwords need 8 to 72 characters with uppercase, lowercase and a digit.

### 7. Profile and email change

```http
GET   /me
PATCH /me       { "first_name": "...", "last_name": "...", "phone": "...", "time_zone": "America/Sao_Paulo" }
PATCH /me/email { "email": "new@example.com", "current_password": "..." }   -> 202
POST  /auth/email/confirm { "token": "..." }
```

`time_zone` is an IANA name (`America/Sao_Paulo` by default, `inclusion` for anything else) that features such as reminders use to pick the user's local time. Only `GET /me` returns it, and anonymization resets it.

The new email only takes effect after the link sent to it (`FRONTEND_URL/confirm-email-change?token=...`) is confirmed. The current address gets a notice. `GET /me` shows `pending_email` meanwhile.

### 8. Account lockout and rate limiting

- 5 wrong passwords (or 2FA codes) lock the account for 15 minutes, doubling up to 24 hours. A locked account answers like a wrong password and the owner is emailed. Admins can unlock with `POST /admin/users/:id/unlock`.
- Rack::Attack limits login per IP and per email, 2FA attempts, refresh, sign-up, confirmation, password recovery and sensitive `/me` actions. Throttled requests get `429 rate_limited` with `Retry-After`.

### 9. Roles and authorization

- Roles: `user` (default) and `admin`. `GET /roles` lists them.
- Public sign-up never creates admins. Admins cannot change their own role or delete themselves.
- New roles: add them to the enum in `app/models/user.rb`, to `roles.*` in `config/locales/en.yml`, and to the policies in `app/policies`.

### 10. Admin area (admin with 2FA)

```http
GET    /admin/users?page=1&limit=20&role=admin&email=ana@example.com&status=deactivated
POST   /admin/users              { "email", "first_name", "password", "role" }   (created already confirmed)
GET    /admin/users/:id
PATCH  /admin/users/:id          { "role": "admin" } or { "password": "..." }
DELETE /admin/users/:id          (anonymizes)
POST   /admin/users/:id/unlock
POST   /admin/users/:id/deactivate   (suspends the account, keeping its data)
POST   /admin/users/:id/reactivate
DELETE /admin/users/:id/two_factor   (lost device: resets 2FA and ends the user's sessions)
GET    /admin/audit_logs?action_name=user.role_changed&actor_id=...&target_id=...&from=2026-10-01&to=2026-10-31
```

Name and phone are encrypted non-deterministically, so the user list can only filter by role, exact email and status (`active` or `deactivated`).

`GET /admin/metrics` (Lar em Dia) answers aggregated counts only, never amounts or descriptions: `users` (`total`, `confirmed`, `active_30d`, `new_30d`, `deactivated`, `with_two_factor`), `engagement` (`with_balance`, `with_entries`, `with_5_series`, `entries_created_30d`) and `signups_by_week` (the last 12 weeks, each from its Monday). Anonymized accounts are left out. The counts come from `AdminMetrics` (`app/services/admin_metrics.rb`).

`GET /admin/categories` (Lar em Dia) lists every category with `active`, inactive ones included (`kind` filters). `POST /admin/categories` creates one and `PATCH /admin/categories/:id` renames it, reorders it (`position`), changes its `default_nature` or turns it off (`active: false` hides it from new entries and keeps the existing ones). There is no delete. `key` and `kind` cannot change after creation (`immutable`), because clients translate by `key`; for a key they do not know they show `name`, so write a new category's `name` in the language the families read. Both actions are audited (`category.created`, `category.updated`).

Deactivating an account sets `deactivated_at`, revokes every session and emails the owner (`account_deactivated`). Until it is reactivated (`account_reactivated` email), login, refresh, social login, email confirmation and the 2FA step answer `401 invalid_credentials`, exactly like a wrong password, without counting as a failed attempt; access tokens already issued answer `401 invalid_token`. Both actions are audited (`user.deactivated`, `user.reactivated`), admins cannot deactivate themselves, and repeating an action returns the user unchanged. Anonymization (`DELETE`) remains the irreversible option.

### 11. Audit log

Every sensitive event is recorded with actor, target, IP, user agent and request id (IP and user agent encrypted): logins and failures, lockouts, logouts, token reuse, registration, confirmation, role, password and email changes, 2FA changes, session revocations, identity unlinks, consents, exports and anonymizations. Records are immutable and never contain personal data in `metadata`. Query them at `GET /admin/audit_logs`.

### 12. Privacy (LGPD)

```http
GET    /me/consents                                   -> current status per kind
POST   /me/consents { "kind": "marketing", "granted": true }
GET    /me/export                                     -> JSON file with every piece of the user's data
DELETE /me { "current_password": "...", "code": "123456 if 2FA is on" }
```

- Consents (`terms`, `privacy`, `marketing`) are versioned (`TERMS_VERSION`, `PRIVACY_VERSION`) and kept as history. Required consents cannot be revoked; closing the account is the way out.
- Deleting an account anonymizes it: personal data is wiped, sessions end, and the technical record stays so the audit trail remains consistent.
- Personal data is encrypted at rest (see `docs/SECURITY.md`).

### 13. Emails

Sent through Sidekiq (`mailers` queue); in development they show up in MailHog. Emails: confirmation, sign-up attempt, welcome, password reset, password changed, email change confirmation and notice, account locked, 2FA disabled. Links point to `FRONTEND_URL`, so lar-em-dia-app must implement `/login`, `/forgot-password`, `/reset-password`, `/confirm-email` and `/confirm-email-change`.

### 14. Scheduled maintenance

`MaintenanceCleanupJob` runs daily at 03:00 (São Paulo) via sidekiq-cron (`config/schedule.yml`): deletes expired refresh tokens and sign-ups unconfirmed for more than 7 days. Scheduled jobs are visible in the Sidekiq dashboard (basic auth with `SIDEKIQ_WEB_USERNAME` / `SIDEKIQ_WEB_PASSWORD`).

### 15. Error monitoring and logs

Set `SENTRY_DSN` to enable Sentry for Rails and Sidekiq. Events carry the exception class, the stacktrace, the request method, URL path and safe headers, the `request_id` tag, the user id and breadcrumbs of what ran before the error (controller, timings, cache hits and SQL statement names). They never carry exception or manual messages (replaced by `[FILTERED]`), request bodies, query strings, cookies, `Authorization`, `X-Token-Transport`, `User-Agent`, the client IP, SQL text, cache keys (Rack::Attack keys contain emails) or Sidekiq job arguments. The policy lives in `lib/sentry_config.rb` and is covered by specs.

Logs are structured JSON in production with no personal data (see "Production"). Find everything about one request by its `request_id`, which is also returned in the `X-Request-Id` response header, stored in audit log entries and attached to Sentry events.

### 16. Resource generator

```bash
bin/rails g api_resource Product name:string price:decimal active:boolean
```

Generates a resource owned by the current user in the shape of trita-api's notes example (removed from this app): migration (UUID key, `user_id`, `null: false` columns, list index), model, policy (owner only, 404 for anyone else), blueprint, paginated CRUD controller, the route in `config/routes/app.rb`, the OpenAPI tag, paths, schemas and response, a factory and request, model and policy specs. The generated code passes the suite at 100% line and branch coverage and RuboCop.

Supported types: `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`. At least one attribute must not be boolean; namespaced names are rejected. Afterwards the generator prints the manual steps: add `has_many` to `User`, and for personal data switch the columns to `text`, add `encrypts`, filter them from logs and list the association in `User::PERSONAL_DATA`.

### 17. Health checks

`GET /health` reports whether the database, the cache and Sidekiq are working (see "Production" for statuses, HTTP codes and where to use it, and `/up` for liveness).

### 18. Social identities and passwordless accounts

An account can be linked to Google or Apple identities and can have no password at all.

```http
GET    /me/identities                                   -> linked providers (id, provider, email_at_link, created_at)
POST   /me/identities { "provider": "google", "id_token": "...", "current_password": "..." } -> 201
DELETE /me/identities/:id { "current_password": "..." } -> 204
```

- `GET /me` returns `password_set`; the front end uses it to offer "set a password" instead of "change password".
- Sensitive actions (`PATCH /me/password`, `PATCH /me/email`, `DELETE /me`, 2FA setup, disable and backup codes, unlinking an identity) re-authenticate with `current_password` when the account has a password. Accounts without a password send the 2FA `code` instead, or a fresh provider ID token (`provider` + `id_token`) of an account already linked to them. An account with none of these gets `reauthentication_unavailable` (422). A wrong token or one that belongs to another account gets `invalid_provider_token` (422), and `provider_unavailable` (422) means the provider could not be reached, so retry.
- `PATCH /me/password` also sets the first password of a passwordless account.
- `POST /me/identities` links a provider account while logged in, even when its email differs from the user's. It re-authenticates with the password or the 2FA code only, because `id_token` is the account being linked; an account that only has Google and no 2FA first sets a password or enables 2FA (both accept the provider token). A provider account can belong to one user, and a user can have one account per provider: otherwise `identity_already_linked` (422).
- The only way to log in cannot be removed: the request fails with `last_login_method` (422).
- Each user can link one identity per provider, and a provider account can belong to one user. The provider's user id is encrypted deterministically (lookup and unique index) and is never returned by the API or the data export; the linked email is encrypted too.
- Identities are listed in `User::PERSONAL_DATA`: they appear in the data export under `content.identities` and are destroyed on anonymization. Unlinking is audited as `identity.unlinked`.

#### Login with Google

```http
POST /auth/oauth/google { "id_token": "...", "accept_terms": true, "accept_privacy": true, "accept_marketing": false }
```

The front end (Google Identity Services on the web, the SDK on mobile) obtains the Google **ID token** and sends it here; the API never redirects. The API checks the signature against Google's keys (cached), the issuer, that the audience is one of `GOOGLE_CLIENT_IDS`, the expiry and that the email is verified. The response is the same as the password login (body or cookie mode).

- Known Google account: logs in.
- Same email as a confirmed account: the identity is linked, the owner is emailed and audited as `identity.linked`.
- Same email as an **unconfirmed** account (possible pre-registration by someone else): the identity is linked, the password and every session of that account are discarded and the email is marked confirmed.
- New email: creates a confirmed account without a password. `accept_terms` and `accept_privacy` are required in this case only (`validation_failed`, `details.accept_terms[].code = required`).
- 2FA still applies: an account with 2FA gets the usual `challenge_token`.
- Errors: `oauth_token_invalid` (401), `oauth_email_unverified` (401), `oauth_provider_unavailable` (503, Google's keys could not be fetched). Throttled to 10 requests per minute per IP.

#### Login with Apple

```http
POST /auth/oauth/apple { "id_token": "...", "first_name": "...", "last_name": "...", "accept_terms": true, "accept_privacy": true }
```

Same flow, rules and errors as Google, with the Apple identity token. Differences:

- Apple does not put the name in the token. It hands it to the app only on the first authorization, so the client sends `first_name` and `last_name` in the body; they are used only when the account is created and only when the token has no name (the token always wins).
- The user may hide the email: the account is then created with an `@privaterelay.appleid.com` address, which never matches an existing account, so no automatic link happens. The first name falls back to `User`. Emails to that address only reach the real inbox if your sending domain is registered with Apple's private email relay service (Apple Developer portal, Sign in with Apple, Email Sources).
- **Account deletion and the Apple token.** App Store rules require revoking the Apple token when an account is deleted. Right before calling `DELETE /me`, have the app run Sign in with Apple again and send the fresh `authorization_code` (and `apple_client_id`, the bundle id or Services ID that produced it, when it is not the first of `APPLE_CLIENT_IDS`):

  ```http
  DELETE /me { "current_password": "...", "apple_authorization_code": "...", "apple_client_id": "com.example.app" }
  ```

  Revocation is best effort and never blocks the deletion: the audit entry `user.anonymized` records `apple_token_revoked` as `true` or `false` (it is absent when the user has no Apple identity or sent no code). Deletions made by an admin cannot revoke anything.

### 19. Categories, balances, entries and projection (Lar em Dia)

```http
GET    /categories?kind=income                     -> active categories by kind and position
GET    /balances?page=1&limit=20                   -> most recent date first
POST   /balances { "amount_cents": -12345, "as_of": "2026-11-03" }
PATCH  /balances/:id
DELETE /balances/:id
GET    /entries?from=2026-11-01&to=2026-11-30&kind=expense&nature=fixed&page=1&limit=100
POST   /entries { "category_id": "...", "description": "November salary", "amount_cents": 650000, "due_on": "2026-11-05", "status": "pending" }
PATCH  /entries/:id { "status": "paid", "paid_on": "2026-11-05" }
DELETE /entries/:id
PATCH  /entries/:id?scope=following { "description": "New rent", "amount_cents": 210000 }
DELETE /entries/:id?scope=all
POST   /entry_series { ...entry fields, "entries_count": 12, "direction": "forward" }
POST   /entry_series { "kind": "installments", "category_id": "...", "description": "Sofa", "total_cents": 120000, "due_on": "2026-11-10", "entries_count": 10 }
GET    /projection?from=2026-11&months=12          -> anchor and one row per month
POST   /projection/simulation { "from": "2026-11", "months": 12, "entries": [ { ...entry or series fields } ] }   -> baseline and simulated
```

- Money is always integer cents (BRL). A balance may be negative; an entry amount is positive and its sign comes from its kind.
- **Categories** are a global catalog. `Category.seed_defaults!` (run by `db:seed`, idempotent and keeping later edits) creates the income categories (`salary`, `thirteenth_salary`, `vacation_bonus`, `bonus`, `extra_income`, `rent_received`, `alimony_received`, `tax_refund`, `reimbursement`, `other_income`) and the expense categories in `Category::DEFAULTS[:expense]`. Expense categories carry a `default_nature`: `fixed` for the keys in `Category::FIXED_EXPENSES` (housing, utilities, internet and phone, subscriptions, education, insurance, health plan, loans), `variable` for the rest; income categories have none. Run `bin/rails db:seed` after deploying to add new defaults. Clients label categories by `key`; `name` is the English label. Inactive categories are hidden and cannot be used by new entries, and a category in use cannot be deleted.
- **Balances** anchor the projection: an amount on a date (today or the past, one per date per user; otherwise `in_future` or `taken`).
- **Entries** are one income or expense on a due date. `kind` is copied from the category, so clients never send it. `status` is `pending` (default) or `paid`; `paid_on` is only accepted when paid (`only_when_paid`). `from`/`to` filter by due date (inclusive) and a malformed date answers `400 invalid_date`. An expense has a `nature` (`fixed` or `variable`) that defaults to its category's `default_nature` and can be overridden; income rejects it (`only_for_expenses`). `nature` filters the list. The description is encrypted at rest and filtered from logs; amounts and dates stay queryable for projections.
- **Recurring series**: `POST /entry_series` takes the fields of `POST /entries` plus `entries_count` (2 to 36, the first entry included) and `direction` (`forward` or `backward`) and creates one entry per month on the same day, or on the month's last day when it is shorter (31 January, 28 February, 31 March). Entries due up to today take the sent status (paid ones with `paid_on` on their due date) and later ones are pending, so replicating a salary backwards records the past months as received. It is all or nothing and answers `{ "data": { "id", "kind": "recurring", "entries_count", "entries": [...] } }`. Every entry carries `series_id` and `series_position` (1 to N by due date). Throttled at 20 per minute per IP (`entry_series/ip`).
- **Installments**: `POST /entry_series` with `kind: installments` (expenses only, otherwise `only_for_expenses` on `kind`) takes `total_cents` instead of `amount_cents` and 2 to 48 `entries_count`, always forwards (`direction` is ignored). The total is split into equal installments and the leftover cents go to the first one (R$ 100,00 in 3 is 33,34 + 33,33 + 33,33); the total needs at least one cent per installment, and a recurring series rejects it (`present`). The series answers its `total_cents`, and every entry carries `series_kind` and `series_count` so clients can show "3/10".
- **Projection** answers `{ "data": { "anchor": { "amount_cents", "as_of" } | null, "months": [ { "month", "opening_cents", "income_cents", "expense_cents", "fixed_expense_cents", "variable_expense_cents", "closing_cents", "savings_cents", "negative" } ], "alerts": { "first_negative_month", "negative_months_count" } } }`. `negative` marks a month that closes below zero and `alerts` sums them up (`first_negative_month` is `null` when no month goes negative). `savings_cents` is the accumulated savings: income minus expenses from the first projected month through that month (it may be negative). The anchor is the most recent balance (zero and `null` without one). A month closes at the anchor plus income minus expenses due between the anchor date and the month's last day, worked backwards for months before the anchor; pending and paid entries both count by due date. `from` (`YYYY-MM`, default the current month) and `months` (1 to 24, default 12) answer `400 invalid_month` and `400 invalid_months` when malformed. The sums run in SQL (`Projection` in `app/services/projection.rb`).
- **Editing or deleting a series**: `PATCH`, `PUT` and `DELETE /entries/:id` take `scope` (`one`, the default, `following` or `all`; ignored outside a series). With `following` or `all`, an edit applies `category_id`, `nature`, `description` and `amount_cents` to this entry and the following ones, or to the whole series, and a new `due_on` moves each one by the same offset with the month end adjustment (moving the 31st to the 30th gives 28 February). It runs in one transaction. `status` and `paid_on` only change one entry at a time (`only_for_single_entry`), and so does an installment's amount, since it would change the total (`installment_amount_locked`); sending them unchanged is fine, so a client can send the whole form. Deleting with `following` removes this entry and the following ones and updates `entries_count` (and `total_cents` of installments); `all` deletes the series. A series left without entries is deleted. Marking an entry as paid is `PATCH /entries/:id { "status": "paid", "paid_on": "..." }`, and back to pending `{ "status": "pending", "paid_on": null }`.
- **What-if simulation**: `POST /projection/simulation` takes `from` and `months` (as `GET /projection`) and `entries`, 1 to 10 hypothetical items (`blank` or `too_long` on `entries` otherwise). An item with `entries_count` is a series with the fields of `POST /entry_series` (recurring or installments); without it, a single entry with the fields of `POST /entries`. Items are validated like the real endpoints, with errors keyed by position (`entries.0.amount_cents`), built in memory (`ProjectionSimulation`) and never saved. The answer is `{ "data": { "baseline": <projection>, "simulated": <projection> } }`, both in the `GET /projection` format with their own `alerts`. To keep a simulation, the client sends the same items to `POST /entries` or `POST /entry_series`. Throttled at 30 per minute per IP (`projection/simulation/ip`).
- Each record belongs to the current user (another user's id answers 404, also for admins). Balances, entries and entry series are listed in `User::PERSONAL_DATA`: exported under `content.balances`, `content.entries` and `content.entry_series` and deleted on anonymization.

### 20. Due-date email alerts (Lar em Dia)

```http
GET   /me/notification_settings                -> { "due_alerts_enabled": true, "due_alert_days_before": 1 }
PATCH /me/notification_settings { "due_alerts_enabled": true, "due_alert_days_before": 3 }
POST  /me/notification_settings/unsubscribe { "token": "..." }   (no login)
```

- `DueAlertsJob` runs every hour (`config/schedule.yml`). It picks the time zones where it is 8h now (`users.time_zone`), and for each confirmed, active user there with alerts on it looks for pending expenses due `due_alert_days_before` days ahead (0 to 7, `inclusion` otherwise; 0 is the same day). When there are some, it sets `users.due_alerts_sent_on` to the user's local date (so a user gets at most one alert a day) and enqueues `DueAlertMailer.upcoming(user)`. The job receives no arguments in production and the mailer only the user: it reads the entries itself.
- The email lists each bill's description and amount, links to `FRONTEND_URL/expenses` and carries an unsubscribe link, `FRONTEND_URL/unsubscribe?token=...`, valid for 60 days. The front end posts that token to `/me/notification_settings/unsubscribe`, which turns the alerts off without a login (`invalid_unsubscribe_token`, 401, for a bad or expired link). The link goes through the front end so that mail scanners following links do not unsubscribe anyone.
- Every change is audited as `user.notification_settings_changed` with the changed fields and `via` (`settings` or `unsubscribe_link`). The unsubscribe endpoint is throttled at 10 per minute per IP (`notification_settings/unsubscribe/ip`).
