# trita-api

Base API (Rails 8.1, API-only) for the Trita apps. The front end lives in the separate **trita-web** project (Node).

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
    api/v1/me/       sessions, two_factor, consents
    api/v1/admin/    users, audit_logs
    api/v1/notes_controller.rb   example domain module (see feature 16)
  jobs/              MaintenanceCleanupJob
  mailers/           UserMailer
  models/            User, RefreshToken, AuditLog, Consent, Current, Note (example)
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
| `name` | `Trita` | Email subjects, default sender name, the 2FA account label in authenticator apps |
| `slug` | `trita` | JWT issuer (`trita-api`), refresh cookie (`trita_refresh`), database names (`trita_api_development`), Redis cache namespace, data export file name, Swagger page title |
| `domain` | `trita.dev` | Default sender `no-reply@<domain>` and the seed users' emails |

`slug` must start with a letter and contain only lowercase letters and digits, because it becomes part of database, cookie, container and image names. Code reads the values through `Rails.configuration.x.app`.

To rename the app after forking, run `bin/rename SLUG [--name NAME] [--domain DOMAIN]` (for example `bin/rename acme`, or `bin/rename minhaloja --name "Minha Loja" --domain minhaloja.com.br`). It rewrites `config/app.yml`, the `TritaApi` module, the Compose project and image names and every mention in `README.md`, `docs/` and `.claude/CLAUDE.md`, validates everything before writing, and prints the manual steps that remain (new secrets, security contact, git remotes, databases). Name defaults to the capitalized slug and domain to `SLUG.dev`.

Starting a new app from this base: follow [docs/FORKING.md](docs/FORKING.md) (repository and `upstream` remote, rename, secrets, first boot, where to put domain code, pulling fixes from the base).

## Production

`Dockerfile` (multi-stage, non-root) is for production; `Dockerfile.dev` is used by docker-compose.

The app refuses to boot in production unless these are set and strong enough: `DATABASE_URL`, `REDIS_URL`, `SIDEKIQ_REDIS_URL`, `JWT_SECRET` (64+), `AR_ENCRYPTION_*` (32+), `APP_HOSTS`, `CORS_ORIGINS` (https only), `FRONTEND_URL`, `MAILER_FROM`, `SMTP_ADDRESS`, `SIDEKIQ_WEB_USERNAME`, `SIDEKIQ_WEB_PASSWORD` (16+). Optional: `SENTRY_DSN`, `JWT_SECRET_PREVIOUS`, `ENABLE_API_DOCS`, `TERMS_VERSION`, `PRIVACY_VERSION`.

---

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

### 3. Cookie mode for browsers (recommended for trita-web)

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

A Node BFF can instead use the default body mode and keep the refresh token in its own server-side cookie.

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
PATCH /me       { "first_name": "...", "last_name": "...", "phone": "..." }
PATCH /me/email { "email": "new@example.com", "current_password": "..." }   -> 202
POST  /auth/email/confirm { "token": "..." }
```

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
GET    /admin/users?page=1&limit=20&role=admin&email=ana@example.com
POST   /admin/users              { "email", "first_name", "password", "role" }   (created already confirmed)
GET    /admin/users/:id
PATCH  /admin/users/:id          { "role": "admin" } or { "password": "..." }
DELETE /admin/users/:id          (anonymizes)
POST   /admin/users/:id/unlock
DELETE /admin/users/:id/two_factor   (lost device: resets 2FA and ends the user's sessions)
GET    /admin/audit_logs?action_name=user.role_changed&actor_id=...&target_id=...&from=2026-10-01&to=2026-10-31
```

Name and phone are encrypted non-deterministically, so the user list can only filter by role and exact email.

### 11. Audit log

Every sensitive event is recorded with actor, target, IP, user agent and request id (IP and user agent encrypted): logins and failures, lockouts, logouts, token reuse, registration, confirmation, role, password and email changes, 2FA changes, session revocations, consents, exports and anonymizations. Records are immutable and never contain personal data in `metadata`. Query them at `GET /admin/audit_logs`.

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

Sent through Sidekiq (`mailers` queue); in development they show up in MailHog. Emails: confirmation, sign-up attempt, welcome, password reset, password changed, email change confirmation and notice, account locked, 2FA disabled. Links point to `FRONTEND_URL`, so trita-web must implement `/login`, `/forgot-password`, `/reset-password`, `/confirm-email` and `/confirm-email-change`.

### 14. Scheduled maintenance

`MaintenanceCleanupJob` runs daily at 03:00 (São Paulo) via sidekiq-cron (`config/schedule.yml`): deletes expired refresh tokens and sign-ups unconfirmed for more than 7 days. Scheduled jobs are visible in the Sidekiq dashboard (basic auth with `SIDEKIQ_WEB_USERNAME` / `SIDEKIQ_WEB_PASSWORD`).

### 15. Error monitoring

Set `SENTRY_DSN` to enable Sentry for Rails and Sidekiq. Only the user id is sent; request bodies, cookies, query strings and auth headers are stripped.

### 16. Notes (example domain module)

A small resource that shows every convention a new feature follows; remove it when starting a real app (see "Removing the example module" in `docs/FORKING.md`).

```http
GET    /notes?page=1&limit=20
POST   /notes          { "title": "Groceries", "body": "Milk" }
GET    /notes/:id
PATCH  /notes/:id      { "title": "Renamed" }
DELETE /notes/:id
```

- Each note belongs to the current user, taken from the session; a `user_id` in the body is ignored.
- Another user's note answers `404 not_found` (not 403), even for admins, so ids cannot be probed.
- `title` (required, up to 200) and `body` (up to 10,000) are encrypted at rest and filtered from logs.
- Listed in `User::PERSONAL_DATA`: included under `content.notes` in `GET /me/export` and deleted when the account is anonymized.
- Routes live in `config/routes/app.rb`; the code is `Note`, `NotePolicy`, `NoteBlueprint` and `Api::V1::NotesController`, with request, model and policy specs.

### 17. Resource generator

```bash
bin/rails g api_resource Product name:string price:decimal active:boolean
```

Generates a resource owned by the current user in the shape of the notes example: migration (UUID key, `user_id`, `null: false` columns, list index), model, policy (owner only, 404 for anyone else), blueprint, paginated CRUD controller, the route in `config/routes/app.rb`, the OpenAPI tag, paths, schemas and response, a factory and request, model and policy specs. The generated code passes the suite at 100% line and branch coverage and RuboCop.

Supported types: `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`. At least one attribute must not be boolean; namespaced names are rejected. Afterwards the generator prints the manual steps: add `has_many` to `User`, and for personal data switch the columns to `text`, add `encrypts`, filter them from logs and list the association in `User::PERSONAL_DATA`.
