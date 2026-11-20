# laremdia-api

API (Rails 8.1, API-only) for **Lar em Dia**, a family budgeting and cash-flow projection app, forked from [trita-api](https://github.com/gabrieltrita/trita-api). The front end lives in the separate **lar-em-dia-app** project (Flutter: web, Android and iOS).

## Stack

| Service | Purpose | Default URL |
|---|---|---|
| **api** | Rails 8.1 / Puma | http://localhost:3000 |
| **sidekiq** | Background jobs and scheduled jobs (sidekiq-cron) | dashboard at http://localhost:3000/sidekiq (in production only with `ENABLE_SIDEKIQ_WEB=true`) |
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

The suite also runs in parallel with `parallel_tests`, one process per CPU, each with its own database (`<slug>_api_test`, `<slug>_api_test2`, ...), which is how CI runs it:

```bash
bin/rails parallel:create parallel:load_schema
bundle exec parallel_rspec
```

Run `bin/rails parallel:load_schema` again after a migration, and pass `-n 2` to choose the number of processes. Each run records how long every spec file took in `tmp/parallel_runtime_rspec.log` (`.rspec_parallel`) and the next run splits the files by those times; CI keeps the log in its cache. SimpleCov merges the processes' results before checking 100% (`.simplecov` only merges in parallel runs, so a serial run never mixes in stale results), and `spec/support/parallel_openapi_coverage.rb` sends each process's covered requests and responses to the first process, which checks the API contract coverage. Avoid `bin/rails parallel:setup`: it also runs the seeds.

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
  jobs/              MaintenanceCleanupJob, DueAlertsJob, MarketDataSyncJob, InterestRateSyncJob
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

The app refuses to boot in production unless these are set and strong enough: `DATABASE_URL`, `REDIS_URL`, `SIDEKIQ_REDIS_URL`, `SECRET_KEY_BASE` (64+, `bin/rails secret`), `JWT_SECRET` (64+), `AR_ENCRYPTION_*` (32+), `APP_HOSTS`, `CORS_ORIGINS` (https only), `FRONTEND_URL`, `MAILER_FROM`, `SMTP_ADDRESS`, `SIDEKIQ_WEB_USERNAME`, `SIDEKIQ_WEB_PASSWORD` (16+). Optional: `SENTRY_DSN`, `DISABLED_CRON_JOBS` (comma-separated job names from `config/schedule.yml` that this environment does not schedule; staging sets `market_data_sync,interest_rate_sync`), `JWT_SECRET_PREVIOUS`, `ENABLE_API_DOCS`, `ENABLE_SIDEKIQ_WEB` (`true` mounts the Sidekiq dashboard at `/sidekiq` in production; off by default, turn it on only while you need it), `TERMS_VERSION`, `PRIVACY_VERSION`, `GOOGLE_CLIENT_IDS` (comma-separated Google OAuth client ids: web, iOS, Android; empty disables Google login), `APPLE_CLIENT_IDS` (comma-separated Apple identifiers: the app's bundle id and the web Services ID; empty disables Apple login), `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` (the Sign in with Apple key: team id, key id and the contents of the `.p8` file with `\n` instead of line breaks; all three or none, used to revoke the Apple token when an account is deleted).

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

`config/deploy.yml` runs the API (`web`) and Sidekiq (`job`) behind kamal-proxy with automatic TLS, plus Postgres 17, Redis 7 and a daily database backup as accessories on the same server, with no published ports. The app name comes from `config/app.yml`; everything specific to your server comes from the environment of the machine that runs `bin/kamal`, never from the repository.

Before the first deploy: an Ubuntu server reachable by SSH key with ports 80 and 443 open, a DNS A record for the API host, and a GitHub token with `write:packages` (images go to `ghcr.io`).

Variables to export (shell or password manager; `.kamal/secrets` only holds references to them, never write a value in it): `DEPLOY_HOST`, `DEPLOY_SSH_USER` (default `root`), `DEPLOY_ARCH` (default `amd64`), `APP_HOST`, `KAMAL_REGISTRY_USERNAME`, `KAMAL_REGISTRY_PASSWORD`, `CORS_ORIGINS`, `FRONTEND_URL`, `MAILER_FROM`, `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, every secret listed in the production section above, `POSTGRES_PASSWORD` and `REDIS_PASSWORD`, plus the optional ones (`SENTRY_DSN`, `GOOGLE_CLIENT_IDS`, `APPLE_*`). The connection strings carry the passwords, so you build them:

- `DATABASE_URL`: `postgres://postgres:<POSTGRES_PASSWORD>@<slug>-api-db:5432/<slug>_api_production`
- `REDIS_URL`: `redis://:<REDIS_PASSWORD>@<slug>-api-redis:6379/1`
- `SIDEKIQ_REDIS_URL`: the same with `/0`

Commands: `bin/kamal setup` the first time (installs Docker, boots the accessories, the proxy and the app), `bin/kamal deploy` afterwards, `bin/kamal rollback VERSION`, and the aliases `bin/kamal console`, `shell`, `logs` and `dbc`. The web container runs `db:prepare` on start, so migrations apply on every deploy.

Changing `SECRET_KEY_BASE` invalidates every user's 2FA backup codes.

### Database backups

The `backup` accessory (the same `postgres:17` image, with `DATABASE_URL`) runs `config/db_backup.sh` when it boots and then every 24 hours, retrying after an hour when a dump fails (for example while Postgres is still starting). Each run writes `pg_dump --no-owner --no-acl`, gzipped, to `<YYYY-MM-DD>.sql.gz` in `~/<service>-backup/backups` on the server (`<slug>-api-backup`, or `<slug>-api-staging-backup` for staging), through a `.partial` file so a failed dump never replaces a good one, and deletes dumps older than `BACKUP_RETENTION_DAYS` (14). `bin/kamal setup` boots it; on a server that was set up before it existed, run `bin/kamal accessory boot backup` (or the Deploy workflow by hand, which runs `kamal setup`).

The dumps live on the same disk as the database, so they cover mistakes and bad migrations, not the loss of the server: copy them elsewhere from time to time (`scp`). `bin/kamal backups` lists them. To restore one into an empty database, stop the app (`bin/kamal app stop`), open a shell in the accessory (`bin/kamal accessory exec backup --interactive --reuse bash`), run `gunzip -c /backups/2026-11-08.sql.gz | psql --single-transaction "$DATABASE_URL"` there, and start the app again (`bin/kamal app boot`). A dump only reads back with the same `AR_ENCRYPTION_*` keys, which are not in it.

### Staging with Kamal

`bin/kamal setup -d staging` and `bin/kamal deploy -d staging` use `config/deploy.staging.yml` on top of `config/deploy.yml`: service `<slug>-api-staging` with its own Postgres and Redis containers, database `<slug>_api_staging`, `ENABLE_API_DOCS=true`, so Swagger is at `/docs`, and `DISABLED_CRON_JOBS=market_data_sync,interest_rate_sync`, so staging does not download B3, CVM and Central Bank data every day on top of production. `DISABLED_CRON_JOBS` takes job names from `config/schedule.yml`, separated by commas; Sidekiq removes them from the schedule when it starts. Import quotes in staging by hand with `bin/kamal app exec -d staging 'bin/rails "market_data:sync[2026-11-11,true]"'` (both arguments are optional: the date defaults to the previous weekday and `true` also refreshes the CVM registry), and interest rates with `bin/kamal app exec -d staging 'bin/rails interest_rates:sync'`. Staging can share the server with production or use another one, because `DEPLOY_HOST` comes from your environment.

`.kamal/secrets.staging` reads every secret from a variable with the `STAGING_` prefix (`STAGING_JWT_SECRET`, `STAGING_DATABASE_URL`, `STAGING_POSTGRES_PASSWORD`, ...), so production and staging secrets can live side by side and one can never be used for the other by mistake; only `KAMAL_REGISTRY_PASSWORD` is shared. The variables that are not secrets keep their names (`DEPLOY_HOST`, `APP_HOST`, `CORS_ORIGINS`, `FRONTEND_URL`, ...): export the staging values before the command.

- `STAGING_DATABASE_URL`: `postgres://postgres:<STAGING_POSTGRES_PASSWORD>@<slug>-api-staging-db:5432/<slug>_api_staging`
- `STAGING_REDIS_URL`: `redis://:<STAGING_REDIS_PASSWORD>@<slug>-api-staging-redis:6379/1`, and `STAGING_SIDEKIQ_REDIS_URL` the same with `/0`
- Point `SMTP_ADDRESS` at a test mailbox so staging never emails real users.

Kamal does not warn about a secret that was not exported: it reaches the container empty, `EnvValidator` refuses to boot, the health check fails and the deploy stops with the previous version still running.

### Continuous deployment

`.github/workflows/deploy.yml` runs the CI and then deploys. Nothing deploys on a push: a version tag (`0.3.0`, no `v`) goes to **production**, only if the tagged commit is on `main`, and **staging** only runs by hand (Actions, Deploy, Run workflow on `main`, choosing `staging`). Production has no other gate, so creating the tag is the approval. A job is skipped when its server is not configured (`DEPLOY_HOST` for production, `STAGING_DEPLOY_HOST` for staging). Images are pushed to `ghcr.io` with the workflow token, so no registry token is stored; if the package was first created with a personal token, give this repository access to it in the package settings.

The first setup of each environment also runs from GitHub: Actions, Deploy, Run workflow on `main`, choosing `staging` or `production` and ticking `setup`. Production runs by hand only with `setup`, so a normal production deploy always needs a tag. That run connects with the same deploy key, prepares the server with `.github/actions/kamal-deploy/prepare-server.sh` (installs Docker when it is missing, adds the deploy user to the `docker` group and opens ports 80 and 443 in iptables, saving the rules when `netfilter-persistent` is there, as on Oracle Cloud images) and then runs `bin/kamal setup` instead of `bin/kamal deploy`. It is safe to run again. Tags and manual runs without `setup` run `bin/kamal deploy`. When `DEPLOY_ARCH` is `arm64` (Ampere, Graviton), the job runs on GitHub's native arm64 runner (`ubuntu-24.04-arm`), so native gems compile without emulation. Kamal keeps the build layers in a registry cache next to the image (`<image>-build-cache-<arch>` on ghcr.io, `mode=max` so the gem layer is kept too), so a deploy that does not touch `Gemfile.lock` skips `bundle install`. `bin/kamal setup` from your machine still works the same way.

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

Releasing: promote `dev` with a `release/YYYY-MM-DD` branch and a PR to `main`; the merge deploys nothing; to try it first, run the Deploy workflow by hand on `main` for `staging`; then `git tag 0.3.0 origin/main && git push origin 0.3.0` deploys production.

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

- 5 wrong passwords (or 2FA codes) lock the account for 15 minutes, doubling up to 24 hours. A locked account answers like a wrong password and the owner is emailed. The email carries a link to `/unlock?token=...` on the front end, which calls `POST /auth/unlock`: it unlocks the account and signs in (still asking for the 2FA code when enabled), so someone who only knows the email cannot keep the owner out. The link stops working once the account is unlocked or locked again. Admins can unlock with `POST /admin/users/:id/unlock`.
- Rack::Attack limits login per IP and per email, 2FA attempts, refresh, sign-up, confirmation, password recovery and sensitive `/me` actions. Every IP also has a general limit of 120 requests per minute (`req/ip`). Throttled requests get `429 rate_limited` with `Retry-After`, the seconds left until the current window ends.

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

Sent through Sidekiq (`mailers` queue); in development they show up in MailHog. Emails: confirmation, sign-up attempt, welcome, password reset, password changed, email change confirmation and notice, account locked, 2FA disabled. Links point to `FRONTEND_URL`, so lar-em-dia-app must implement `/login`, `/forgot-password`, `/reset-password`, `/confirm-email`, `/confirm-email-change` and `/unlock`.

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
GET    /entries?from=2026-11-01&to=2026-11-30&kind=expense&nature=fixed&page=1&limit=500
POST   /entries { "category_id": "...", "description": "November salary", "amount_cents": 650000, "due_on": "2026-11-05", "status": "pending" }
PATCH  /entries/:id { "status": "paid", "paid_on": "2026-11-05" }
DELETE /entries/:id
PATCH  /entries/:id?scope=following { "description": "New rent", "amount_cents": 210000 }
DELETE /entries/:id?scope=all                                  -> { "data": { "deleted_ids": [...] }, "meta": { "entries": [...] } }
POST   /entries?projection_from=2026-05&projection_months=36 { ... }   -> the entry and meta.projection
POST   /entry_series { ...entry fields, "entries_count": 12, "direction": "forward" }
POST   /entry_series { ...entry fields, "entries_count": 5, "direction": "forward", "interval_months": 12 }
POST   /entry_series { "kind": "installments", "category_id": "...", "description": "Sofa", "total_cents": 120000, "due_on": "2026-11-10", "entries_count": 10 }
GET    /projection?from=2026-11&months=12          -> anchor and one row per month
POST   /projection/simulation { "from": "2026-11", "months": 12, "entries": [ { ...entry or series fields } ] }   -> baseline and simulated
```

- Money is always integer cents (BRL). A balance may be negative; an entry amount is positive and its sign comes from its kind.
- **Categories** are a global catalog. `Category.seed_defaults!` (run by `bin/rails categories:seed`, which `db:prepare` and `db:seed` also run, idempotent and keeping later edits) creates the income categories (`salary`, `thirteenth_salary`, `vacation_bonus`, `bonus`, `extra_income`, `rent_received`, `alimony_received`, `tax_refund`, `reimbursement`, `other_income`) and the expense categories in `Category::DEFAULTS[:expense]`. Expense categories carry a `default_nature`: `fixed` for the keys in `Category::FIXED_EXPENSES` (housing, utilities, internet and phone, subscriptions, education, insurance, health plan, loans), `variable` for the rest; income categories have none. Every deploy runs `db:prepare` when the web container boots, so new environments start with the categories and new defaults appear on the next deploy. Clients label categories by `key`; `name` is the English label. Inactive categories are hidden and cannot be used by new entries, and a category in use cannot be deleted.
- **Balances** anchor the projection: an amount on a date (today or the past, one per date per user; otherwise `in_future` or `taken`).
- **Entries** are one income or expense on a due date. `kind` is copied from the category, so clients never send it. `status` is `pending` (default) or `paid`; `paid_on` is only accepted when paid (`only_when_paid`). `from`/`to` filter by due date (inclusive) and a malformed date answers `400 invalid_date`. An expense has a `nature` (`fixed` or `variable`) that defaults to its category's `default_nature` and can be overridden; income rejects it (`only_for_expenses`). `nature` filters the list. The description is encrypted at rest and filtered from logs; amounts and dates stay queryable for projections.
- **Recurring series**: `POST /entry_series` takes the fields of `POST /entries` plus `entries_count` (2 to 36, the first entry included) and `direction` (`forward` or `backward`) and creates one entry per month on the same day, or on the month's last day when it is shorter (31 January, 28 February, 31 March). `interval_months` (1, the default, 3, 6 or 12, otherwise `inclusion`) repeats it in fixed months instead: a yearly FGTS withdrawal is `{ "due_on": "2027-05-10", "entries_count": 5, "interval_months": 12 }`, and a 13th salary paid in September and December is two yearly series, since each half has its own amount. Entries due up to today take the sent status (paid ones with `paid_on` on their due date) and later ones are pending, so replicating a salary backwards records the past months as received. It is all or nothing and answers `{ "data": { "id", "kind": "recurring", "interval_months", "entries_count", "entries": [...] } }`. Every entry carries `series_id` and `series_position` (1 to N by due date). Throttled at 20 per minute per IP (`entry_series/ip`).
- **Changes answer what changed**: `POST`, `PATCH`/`PUT` and `DELETE` on `/balances` and `/entries`, and `POST /entry_series`, accept `projection_from` and `projection_months` (the same values as `from` and `months` in `GET /projection`, `400 invalid_month`/`invalid_months` otherwise, checked before anything is saved). With either one the answer carries `meta.projection`, recalculated after the change in the `GET /projection` format, so a client keeps its cached projection current with a single request. `DELETE` answers `200` with `data.deleted_ids`. Changing or deleting an entry of a series also answers `meta.entries`, every entry left in the series, because `following` and `all` change other entries and deleting updates `series_count`. `GET /entries` accepts `limit` up to 500 so a client can load several months in one page.
- **Installments**: `POST /entry_series` with `kind: installments` (expenses only, otherwise `only_for_expenses` on `kind`) takes `total_cents` instead of `amount_cents` and 2 to 48 `entries_count`, always monthly and forwards (`direction` and `interval_months` are ignored). The total is split into equal installments and the leftover cents go to the first one (R$ 100,00 in 3 is 33,34 + 33,33 + 33,33); the total needs at least one cent per installment, and a recurring series rejects it (`present`). The series answers its `total_cents`, and every entry carries `series_kind` and `series_count` so clients can show "3/10".
- **Projection** answers `{ "data": { "anchor": { "amount_cents", "as_of" } | null, "months": [ { "month", "opening_cents", "income_cents", "expense_cents", "fixed_expense_cents", "variable_expense_cents", "closing_cents", "savings_cents", "negative", "expense_by_category": [ { "category_key", "amount_cents" } ] } ], "alerts": { "first_negative_month", "negative_months_count" }, "last_entry_month" } }`. `expense_by_category` sums the month's expenses by category key, largest first, so clients can chart where the money goes without loading entries. `last_entry_month` is the month of the user's latest due date (`null` without entries). `negative` marks a month that closes below zero and `alerts` sums them up (`first_negative_month` is `null` when no month goes negative). `savings_cents` is the accumulated savings: income minus expenses from the first projected month through that month (it may be negative). The anchor is the most recent balance (zero and `null` without one). A month closes at the anchor plus income minus expenses due between the anchor date and the month's last day, worked backwards for months before the anchor; pending and paid entries both count by due date. `from` (`YYYY-MM`, default the current month) and `months` (1 to 60, default 12, or `all` to project through the month of the last entry, from 1 up to 60 months; simulated entries count in the simulation) answer `400 invalid_month` and `400 invalid_months` when malformed. The sums run in SQL (`Projection` in `app/services/projection.rb`).
- **Editing or deleting a series**: `PATCH`, `PUT` and `DELETE /entries/:id` take `scope` (`one`, the default, `following` or `all`; ignored outside a series). With `following` or `all`, an edit applies `category_id`, `nature`, `description` and `amount_cents` to this entry and the following ones, or to the whole series, and a new `due_on` moves each one by the same offset, keeping the series' interval, with the month end adjustment (moving the 31st to the 30th gives 28 February). It runs in one transaction. `status` and `paid_on` only change one entry at a time (`only_for_single_entry`), and so does an installment's amount, since it would change the total (`installment_amount_locked`); sending them unchanged is fine, so a client can send the whole form. Deleting with `following` removes this entry and the following ones and updates `entries_count` (and `total_cents` of installments); `all` deletes the series. A series left without entries is deleted. Marking an entry as paid is `PATCH /entries/:id { "status": "paid", "paid_on": "..." }`, and back to pending `{ "status": "pending", "paid_on": null }`.
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

### 21. Investments catalog (Lar em Dia)

```http
GET /assets?asset_type=fii&sector=Logística&q=hglg&page=1&limit=20
GET /assets/PETR4   -> ticker, name, asset_type, sector, isin, cnpj, active, quote { quoted_on, close_cents, volume_cents, trades_count }
```

- The catalog (`Asset`, `AssetQuote`) is global and holds no personal data. It lists the shares (ON, PN and units) and FII quotas of B3's cash market in standard lots, one quote per trading day.
- `MarketDataSyncJob` runs at 7h (São Paulo), Tuesday to Saturday (`config/schedule.yml`), and imports the previous weekday's closing quotes from B3's daily COTAHIST file (`MarketData::B3Quotes`). A day without a file (a holiday) is only logged. With Monday's quotes, or when run as `MarketDataSyncJob.perform_later("2026-11-11", with_registry: true)`, it also reads the CVM registry of the current and previous year: the FII monthly report (`MarketData::CvmFunds`, matched by ISIN: CNPJ, name and segment) and the listed companies' FCA (`MarketData::CvmCompanies`, matched by ticker: CNPJ, name and sector). Assets without a quote in the last 30 days become inactive and leave `GET /assets`, but `GET /assets/:ticker` still shows them.
- Downloads (`MarketData::Download`) use 10-second timeouts and size limits, and any failure raises `MarketData::Unavailable`, which retries the job in an hour (3 attempts). Logs carry only counts, the host and the exception class.
- Sources: [B3 historical quotes](https://www.b3.com.br/pt_br/market-data-e-indices/servicos-de-dados/market-data/historico/mercado-a-vista/cotacoes-historicas/) (end-of-day and historical quotes may be redistributed free of charge, B3 Market Data Commercial Policy, items 7.9 and 7.10) and [CVM open data](https://dados.cvm.gov.br/) under the Open Database License (ODbL), which requires citing CVM as the source in the app.

### 22. Investments portfolio (Lar em Dia)

```http
POST   /investment_transactions { "ticker": "PETR4", "kind": "buy", "traded_on": "2026-10-01", "quantity": 100, "price_cents": 3000, "fees_cents": 50, "debit_balance": true }
GET    /investment_transactions?ticker=PETR4&from=2026-01-01&to=2026-12-31
PATCH  /investment_transactions/:id            DELETE /investment_transactions/:id
PATCH  /investment_positions/PETR4 { "goal": "income" }
GET    /portfolio?goal=growth&include_closed=true
GET    /portfolio/history                      -> [{ "month": "2026-11", "contributed_cents", "market_value_cents" }]
```

- A portfolio is a list of transactions (`InvestmentTransaction`: `buy`, `sell`, `split`, `reverse_split`, `bonus`) grouped in one `InvestmentPosition` per asset, which only stores the goal (`income` or `growth`; FIIs start with `income` and stocks with `growth`, unless the first transaction sends `goal`). Quantity, cost, average price and realized profit are always recomputed by `PositionLedger`: the average price is weighted and includes fees, a sale removes shares at the average price, and splits, reverse splits and bonuses send the shares added or removed without changing the cost. Average prices are integers in `_e8` (hundred-millionths of a real).
- No transaction may leave the position below zero shares on any day: creating or editing answers `validation_failed` with `insufficient_quantity` on `quantity`, and deleting a buy that a later sale needs answers `insufficient_quantity` (422). An unknown ticker answers `unknown_asset` on `ticker`, and the ticker of a saved transaction is `immutable`.
- `debit_balance: true` creates a paid entry on the trade date: an expense in `investment_contribution` for a buy (shares × price + fees) and an income in `investment_redemption` for a sale (shares × price − fees), so the projection counts the cash. Editing the transaction updates it, `debit_balance: false` deletes it, and deleting the entry in the entries screen keeps the transaction.
- `GET /portfolio` values each position at the latest close (`AssetQuote`), or at cost without a quote. `GET /portfolio/history` values the shares held at each month end at the last close up to that day, for at most the last 120 months.
- Month-end quotes before the daily job started come from `bin/rails market_data:backfill[2019]` (`MarketData::Backfill`), which reads B3's monthly COTAHIST files line by line, keeps each asset's last quote of the month and creates delisted assets as inactive. It is idempotent; in production run it once with `bin/kamal app exec 'bin/rails market_data:backfill[2019]'` (about 15 seconds per month). `bin/rails "market_data:sync[DATE,true]"` runs the daily import right away, which is how staging gets quotes, since its schedule leaves the job out (`DISABLED_CRON_JOBS`).
- Transactions and positions are personal data (`User::PERSONAL_DATA`): exported under `content` and destroyed by `anonymize!`. Admin metrics only count users with a portfolio, transactions in the last 30 days and positions by goal.
- The API only records and computes from the user's own data; it never recommends assets. Clients show a notice that the numbers are informational and not investment advice.

### 23. Emergency reserve (Lar em Dia)

```http
POST   /reserve_accounts { "name": "CDB liquidez diária", "kind": "cdb", "cdi_percent_bps": 10500, "tax_exempt": false }
GET    /reserve_accounts                      PATCH /reserve_accounts/:id    DELETE /reserve_accounts/:id
POST   /reserve_movements { "account_id": "…", "kind": "deposit", "moved_on": "2026-10-01", "amount_cents": 100000, "debit_balance": true }
GET    /reserve_movements?account_id=…&from=2026-01-01&to=2026-12-31
GET    /reserve                               -> totals, accounts, suggestion, goal, alerts, rates_as_of
PATCH  /reserve { "goal_months": 6, "goal_cents": null }
GET    /reserve/projection?months=12          -> months (gross and net per account) and assumptions
```

- An account (`ReserveAccount`, name encrypted) is `selic_treasury`, `cdb` (`cdi_percent_bps`, 110% is 11000), `savings`, `idle` or `fixed_rate` (`annual_rate_bps`, 12% is 1200). A missing rate answers `rate_required` and a rate the kind does not use `rate_not_allowed`. `tax_exempt` marks an LCI or LCA; savings and idle money are always exempt.
- Movements (`ReserveMovement`) are `deposit`, `withdrawal` or `anchor` ("today I have X", like a `Balance`: the account restarts from that amount, which counts as one deposit on its date for the income tax). A withdrawal takes the gross amount from the oldest deposits first and cannot exceed what the account holds on its date (`insufficient_reserve`, also when deleting a deposit a later withdrawal needs). `debit_balance: true` creates a paid expense in `reserve_deposit` or a paid income in `reserve_withdrawal`; an anchor refuses it (`anchor_not_allowed`).
- Values are never stored: `ReserveLedger` replays the movements and `ReserveGrowth` grows each deposit with `BigDecimal`, rounding to cents once. Past days use the Central Bank series in `interest_rates` (daily Selic, daily CDI times the CDB percentage, the fixed annual rate over 252 business days, savings on each monthly anniversary with deposits on the 29th to the 31st counting from the 1st); business days not imported yet use the last known rate. Future months use the Selic target, the target minus 0.10 point as the CDI estimate and the last savings yield, with Monday to Friday as business days (holidays ignored).
- The net value subtracts the regressive income tax each deposit would pay if withdrawn that day (22.5% up to 180 days, 20% up to 360, 17.5% up to 720, 15% after); IOF is ignored. Each `GET /projection` month carries `reserve_cents`, the net reserve on its last day.
- `GET /reserve` suggests `reserve_goal_months` (default 6, 1 to 24) times the average fixed expenses of the months that have any among the last three closed months, the current month and the next two (so upcoming bills count too, and a new account with only future bills still gets a suggestion), or uses `reserve_goal_cents` when the user set one; `coverage_months_e2` is the net total over that average in hundredths of a month. Alerts: `no_reserve` (fixed expenses but no account), `below_suggestion` and `idle_money`. Clients word them as suggestions from the user's own data, never as investment advice.
- `InterestRateSyncJob` (8h São Paulo, Tuesday to Saturday) imports the last 15 days of SGS series 11 (Selic), 12 (CDI), 195 (savings) and 432 (Selic target) through `InterestRates::Bcb`. Load the history once with `bin/rails "interest_rates:backfill[2019]"` (one request per series and year) and import right away with `bin/rails interest_rates:sync`. Staging leaves the job out (`DISABLED_CRON_JOBS=market_data_sync,interest_rate_sync`): run `bin/kamal app exec -d staging 'bin/rails interest_rates:sync'` by hand.
- Accounts and movements are personal data (`User::PERSONAL_DATA`). Admin metrics only count users with a reserve and accounts by kind.

### 24. Distributions and passive income (Lar em Dia)

```http
GET    /assets/HGLG11                          -> ..., fund_report, distributions (last 24 months)
POST   /asset_distributions { "ticker": "PETR4", "kind": "jcp", "record_on": "2026-08-20", "paid_on": "2026-11-25", "amount_per_share_e8": 33333333 }
GET    /asset_distributions?ticker=PETR4       PATCH /asset_distributions/:id    DELETE /asset_distributions/:id
GET    /portfolio/income?months=12             -> monthly_average_cents, received, forecast, positions
GET    /projection?include_investment_income=false
```

- FII income comes from the CVM monthly report: with the registry, `MarketDataSyncJob` also reads the complement file (`MarketData::CvmFunds`) and `MarketData::FundReportSync` saves one `FundReport` per fund and month (equity, book value per share in `_e8`, shares and shareholders) and one `AssetDistribution` (`kind: fii_income`, `source: cvm`) worth the month's dividend yield times the book value per share, with the record date on the month's last day and no payment date (it counts in the following month). Load past years with `bin/rails "market_data:fund_reports[2019]"`; it is idempotent and refreshes the indicators at the end.
- There is no free official source of stock dividends and JCP, so users record the ones they receive (`source: manual`, `dividend` or `jcp`, gross value per share in `_e8`). Only stocks of the user's portfolio accept them (`unknown_asset`, `stock_only` on an FII), the payment date cannot precede the record date (`before_record_on`), the ticker is `immutable`, and they count only for that user. They are personal data (`User::PERSONAL_DATA`).
- `DistributionIncome` counts each distribution in its payment month for the shares held on the record date, JCP net of the 15% income tax, and rounds each month to cents once. The forecast for each month after the current one uses the distributions already announced for it or the last 12 months' average per share times the shares held today.
- Every `GET /projection` month carries `investment_income_cents` (the forecast, added to `income_cents` and the balance after the current month unless `include_investment_income=false`; no entries are created, so recording the real income later does not count twice in past months), `investments_value_cents` (the portfolio as in `GET /portfolio/history`, repeating today's value in future months without forecasting appreciation) and `net_worth_cents` (closing balance plus reserve plus portfolio).

### 25. Indicators, screener and simulators (Lar em Dia)

```http
GET    /assets?asset_type=fii&paying=true&dy_12m_bps_min=800&p_vp_e2_max=100&sort=dy_12m_bps
GET    /assets?asset_type=stock&roe_average_bps_min=1500&earnings_cagr_bps_min=500&liquidity_cents_min=100000000&sort=p_l_e2&direction=asc
POST   /portfolio/simulation { "kind": "income", "ticker": "HGLG11", "initial_cents": 1000000, "monthly_cents": 100000, "months": 120, "target_monthly_income_cents": 100000 }
POST   /portfolio/simulation { "kind": "growth", "initial_cents": 1000000, "monthly_cents": 100000, "months": 240, "annual_rate_bps": 800 }
```

- Company statements come from CVM's annual DFP (`MarketData::CvmFinancials`, one zip per year, consolidated statements or the individual ones for companies without subsidiaries, the latest version of each). `CompanyFinancial` keeps one row per CNPJ and fiscal year: revenue (`3.01`), net income (the result "do período"), equity, net debt (loans and financing minus cash and short-term investments; null for banks, whose balance sheets have no loans), dividends and JCP paid to the company's shareholders (financing activities of the cash flow statement) and shares outside treasury. On registry runs `MarketDataSyncJob` imports last year's DFP; load past years with `bin/rails "market_data:financials[2019]"`. Quarterly reports (ITR) are not imported yet.
- `AssetIndicators` refreshes one `AssetIndicator` per listed asset after every sync (`bin/rails market_data:indicators` by hand): FIIs get DY 12m, average and median monthly distribution, consecutive years paying (0 when the latest distribution is older than last year) and P/VP from the latest monthly report; stocks get DY and payout of the last fiscal year, consecutive years paying, P/VP, P/L, average ROE, earnings and equity CAGR (up to 5 years, at least 2), years with profit, net margin and net debt over equity. Every asset gets the 30-day average traded volume. Some companies report the share count in thousands; a market value below 1% of equity is read that way.
- `GET /assets` returns `indicators` for each asset and filters by `<indicator>_min` / `<indicator>_max` (`invalid_filter` when not an integer), `paying=true` (positive DY, which leaves out FIIs still in development, since CVM's "Mandato" field is empty) and sorts by any indicator (`invalid_sort`). It only filters and sorts: there is no ranking or recommendation.
- `POST /portfolio/simulation` saves nothing. `income` buys whole shares every month at the latest close and pays the FII's average monthly distribution (or a twelfth of a stock's DY), reinvesting by default, and answers the shares and capital needed for `target_monthly_income_cents`; without `ticker` it applies `monthly_yield_bps`. `growth` compounds the contributions at the rate the user chose. Neither forecasts prices.

### 26. Leftover balance split (Lar em Dia)

```http
POST   /allocation_targets { "name": "Renda fixa", "mode": "percent", "percent_bps": 1000 }
POST   /allocation_targets { "name": "Caridade", "mode": "fixed", "amount_cents": 1000 }
POST   /allocation_targets { "name": "Reserva", "mode": "remainder", "reserve_account_id": "…" }
GET    /allocation_targets                    PATCH /allocation_targets/:id    DELETE /allocation_targets/:id
GET    /allocation_plan?month=2026-11         -> month, closing_cents, base_cents, used_cents, planned_cents, unallocated_cents, items
POST   /allocations { "target_id": "…", "month": "2026-11", "amount_cents": 752 }
DELETE /allocations/:id
```

- Destinations (`AllocationTarget`, name encrypted) take a `fixed` amount, a `percent` of the month's balance (`percent_bps`, 10% is 1000) or the `remainder`, at most one per user. The value the mode does not use must be absent (`blank`, `present`). `position` orders them; a new destination goes last.
- `AllocationPlan` starts from the month's projected closing balance (the same number as `GET /projection`) and adds back what was already used that month, so marking one destination never shrinks the others. Used destinations keep their amount; the others are planned in order up to what is left, and the remainder takes the rest. A month closing at zero or below plans nothing.
- Marking a destination as used (`Allocation`, once per destination and month, never in a future month: `in_future`) records the planned amount, or the one sent, as a paid expense in the new `surplus_allocation` category (today in the current month, the month's last day in past months), so it comes out of the closing balance. A destination linked to a reserve account goes through `ReserveMovementRecorder` as a deposit with `debit_balance`. Undoing it deletes that expense or deposit (`insufficient_reserve` when a later withdrawal needs it), and deleting the expense from the entries list also undoes it. Deleting a destination keeps the money already used.
- Destinations and allocations are personal data (`User::PERSONAL_DATA`).
