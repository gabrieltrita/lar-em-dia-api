# Starting a new app from trita-api

trita-api is the base every app forks. This guide creates an app (`acme-api` in the examples), keeps it able to receive fixes from the base, and lists what must change before going live.

## 1. Create the repository

```bash
git clone git@github.com:gabrieltrita/trita-api.git acme-api
cd acme-api
git remote rename origin upstream
git remote add origin git@github.com:<owner>/acme-api.git
git push -u origin main
```

Keeping the shared history (instead of GitHub's "Use this template") is what lets the app merge base fixes later. A private repository is fine.

## 2. Rename

```bash
bin/rename acme
bin/rename acme --name "Acme Store" --domain acme.com.br
```

The slug must be lowercase letters and digits. The script updates `config/app.yml`, the application module, the Compose project and the docs, and prints the remaining manual steps. Everything else (JWT issuer, refresh cookie, database names, Redis namespace, email sender, 2FA label) derives from `config/app.yml`. See "App identity" in the README.

## 3. Secrets and `.env`

```bash
cp .env.example .env
```

Replace every `troque-me` with a new value; never reuse the base's values:

| Variable | How to generate |
|---|---|
| `JWT_SECRET` | `bin/rails secret` |
| `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT` | `bin/rails db:encryption:init` (use the three printed values) |
| `DATABASE_PASSWORD`, `REDIS_PASSWORD`, `SIDEKIQ_WEB_PASSWORD` | `openssl rand -hex 24` |

`REDIS_PASSWORD` must also be written inside `REDIS_URL` and `SIDEKIQ_REDIS_URL`. If another project already uses the default ports, change `API_PORT`, `DB_PORT`, `REDIS_PORT`, `MAILHOG_SMTP_PORT`, `MAILHOG_WEB_PORT` and `ADMINER_PORT` (and `DATABASE_PORT`/`SMTP_PORT` for host runs).

The encryption keys protect every personal field. Store them in a password manager: losing them makes the data unreadable, and changing the deterministic key later needs the procedure in `docs/SECURITY.md`.

## 4. First boot

```bash
docker compose up -d --build
docker compose exec api bin/rails db:seed
docker compose exec api bundle exec rspec
```

The api container runs `db:prepare` on start. The seed creates the admin (`ADMIN_EMAIL`, default `admin@<domain>`) and, in development, `user@<domain>`. The admin must enable 2FA (`POST /api/v1/me/two_factor/setup` then `/enable`) before using `/api/v1/admin/*`. The suite must pass with 100% line and branch coverage before any domain code is added.

## 5. What else to change

- `docs/SECURITY.md`: the security contact.
- `FRONTEND_URL` and `CORS_ORIGINS`: the app's front end.
- `SENTRY_DSN`: a Sentry project for this app (optional).
- `TERMS_VERSION`, `PRIVACY_VERSION`: the app's own documents; bumping a version makes users accept again.
- `.claude/CLAUDE.md`: the repository line in the rules and a section describing the app's domain.
- Production variables validated by `EnvValidator` (see "Production" in the README).

## 6. Adding domain code

Add, do not edit. Files you create never conflict with the base; edits to base files can.

- New code lives in new files: models in `app/models`, controllers under `Api::V1::<Feature>`, policies, blueprints and specs next to them.
- Base files are the ones listed in "Project layout" in the README (authentication, users, sessions, 2FA, privacy, audit log, admin). When one must change, keep the edit small, for example a single `has_many :orders` line in `User`.
- Routes: add a block for the app at the end of the `namespace :v1` block in `config/routes.rb`.
- Extension points: `AuditLog::ACTIONS` for new audited events, `config/initializers/rack_attack.rb` for throttles on sensitive endpoints, `Consent::KINDS` for new consents, `docs/openapi.yaml` for every route and error code.
- Follow `.claude/CLAUDE.md`: stable error codes, OpenAPI for every route, 100% coverage.

## 7. Pulling fixes from the base

```bash
git fetch upstream
git merge upstream/main
docker compose exec api bin/rails db:migrate
docker compose exec api bundle exec rspec
```

Expected conflicts and how to resolve them:

| File | Resolution |
|---|---|
| `config/app.yml`, `config/application.rb` (module), `docker-compose.yml` (`name:`, `image:`) | Keep the app's values |
| `README.md`, `docs/*`, `.claude/CLAUDE.md` | Take the base's new content and keep the app's names; running `bin/rename` again is not needed |
| `db/schema.rb` | Take either side, run `bin/rails db:migrate` and commit the regenerated file |
| `Gemfile.lock` | Take the base's version, run `bundle install`, commit the result |
| Base files the app edited | Resolve by hand; the smaller the app's edits, the rarer this is |

Base migrations merged later may have timestamps older or newer than the app's; `bin/rails db:migrate` runs every pending version either way. Merge often: small, frequent merges conflict less.

## 8. Sharing a Redis between apps

The cache (JWT denylist, rate limits) is namespaced by `slug`, so apps can share a Redis for it. Sidekiq has no namespace support: give each app its own database in `SIDEKIQ_REDIS_URL` (`/0`, `/2`, ...) or its own instance. In development each Compose project runs its own Redis.

## 9. Checklist

- [ ] Repository created with `upstream` pointing to trita-api
- [ ] `bin/rename` run and committed
- [ ] `.env` with new secrets; encryption keys stored safely
- [ ] Stack boots, seed runs, suite passes at 100%
- [ ] Admin has 2FA enabled
- [ ] Security contact, front-end URLs, Sentry and consent versions updated
- [ ] `.claude/CLAUDE.md` describes the app
