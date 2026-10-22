# trita-api

API base (Rails 8.1, API-only) para os aplicativos Trita. O front-end fica no projeto separado **trita-web** (Node).

## Stack

| Serviço | Uso | URL (padrão) |
|---|---|---|
| **api** | Rails 8.1 / Puma | http://localhost:3000 |
| **sidekiq** | Jobs em background (e-mails etc.) | painel em http://localhost:3000/sidekiq |
| **db** | PostgreSQL 17 | localhost:5432 |
| **redis** | Cache, fila do Sidekiq, denylist de JWT, rate limit | localhost:6379 |
| **mailhog** | Captura os e-mails enviados em dev | http://localhost:8025 |
| **adminer** | Interface web para o Postgres | http://localhost:8080 |

Gems principais: `jwt`, `bcrypt`, `pundit` (autorização), `rack-cors`, `rack-attack` (rate limit), `sidekiq`, `pagy` (paginação), `blueprinter` (JSON), `rspec-rails`.

## Subindo o ambiente

```bash
cp .env.example .env
# gere segredos novos e cole no .env:
bin/rails db:encryption:init          # AR_ENCRYPTION_*
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'   # JWT_SECRET

docker compose up -d --build
docker compose exec api bin/rails db:seed   # cria o admin (ADMIN_EMAIL / ADMIN_PASSWORD)
```

Se alguma porta já estiver em uso, altere `API_PORT`, `DB_PORT`, `REDIS_PORT`, `MAILHOG_*`, `ADMINER_PORT` no `.env`.

Comandos úteis:

```bash
docker compose logs -f api sidekiq
docker compose exec api bin/rails console
docker compose exec api bundle exec rspec
docker compose exec api bin/rails g model Produto nome:string   # já gera PK uuid, spec e factory
```

Para rodar a API fora do Docker (usando só db/redis/mailhog do compose): `docker compose up -d db redis mailhog` e depois `bin/rails s` — o `.env` já aponta para `localhost`.

## Segurança

**Criptografia dos dados do usuário** — Active Record Encryption (AES-256-GCM):

- `email`: criptografia **determinística** → permite `find_by(email:)`, índice único e login.
- `first_name`, `last_name`, `phone`: **não-determinística** (mais forte). Não dá para filtrar/ordenar por esses campos no SQL.
- `refresh_tokens.user_agent` / `ip_address`: também criptografados.
- Senha: `bcrypt` (`has_secure_password`). Refresh tokens: só o hash SHA-256 fica no banco.
- `support_unencrypted_data = false`: o Rails recusa ler dados em texto puro.

Ao criar novos models com dados pessoais, use `encrypts :campo` (colunas `text`) e adicione o campo em `config/initializers/filter_parameter_logging.rb`.

> As chaves `AR_ENCRYPTION_*` **não podem ser perdidas nem trocadas** sem rotação: sem elas os dados ficam ilegíveis. Em produção guarde-as num secret manager.

**JWT**

- **Access token**: JWT HS256, 15 min (`JWT_ACCESS_TTL_MINUTES`), enviado em `Authorization: Bearer <token>`.
- **Refresh token**: opaco, 30 dias (`JWT_REFRESH_TTL_DAYS`), **rotacionado** a cada uso. Se um refresh token já usado aparecer de novo, todas as sessões do usuário são encerradas (detecção de roubo).
- **Logout**: o `jti` do access token vai para uma denylist no Redis até expirar.
- **Trocar/redefinir senha** invalida todos os tokens emitidos antes.

**Outros**: rate limit em login/cadastro/recuperação de senha (Rack::Attack), CORS restrito a `CORS_ORIGINS`, parâmetros sensíveis filtrados dos logs, Sidekiq Web com basic auth.

## Roles

`user` (padrão no cadastro) e `admin`. O cadastro público sempre cria `user`; só um admin promove outro usuário. Um admin não pode rebaixar nem excluir a si mesmo.

Para adicionar roles, inclua no enum de `app/models/user.rb`, nas traduções `roles.*` de `config/locales` e trate nas policies (`app/policies`).

## Endpoints (`/api/v1`)

Respostas de sucesso: `{ "data": ..., "meta": ... }`. Erros: `{ "error": { "code", "message", "details" } }`.

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| POST | `/auth/register` | — | `email, password, password_confirmation, first_name, last_name, phone` → user + tokens |
| POST | `/auth/login` | — | `email, password` → user + tokens |
| POST | `/auth/refresh` | — | `refresh_token` → novos tokens |
| DELETE | `/auth/logout` | ✓ | opcional: `refresh_token` ou `all_devices: true` |
| POST | `/auth/password/forgot` | — | `email` → envia e-mail (sempre 202) |
| POST | `/auth/password/reset` | — | `token, password, password_confirmation` |
| GET | `/me` | ✓ | perfil |
| PATCH | `/me` | ✓ | `email, first_name, last_name, phone` |
| PATCH | `/me/password` | ✓ | `current_password, password, password_confirmation` → novos tokens |
| DELETE | `/me` | ✓ | `current_password` |
| GET | `/roles` | ✓ | lista de roles |
| GET | `/admin/users` | admin | `page, limit, role, email` (paginado) |
| GET/POST/PATCH/DELETE | `/admin/users[/:id]` | admin | CRUD de usuários (inclui `role`) |

Health check: `GET /up`.

Formato dos tokens:

```json
{
  "token_type": "Bearer",
  "access_token": "eyJ...",
  "expires_in": 900,
  "expires_at": "2026-10-19T19:20:00-03:00",
  "refresh_token": "..."
}
```

Sugestão para o **trita-web**: guardar o access token em memória e o refresh token em storage seguro (ou cookie httpOnly do servidor Node). Ao receber 401, chamar `/auth/refresh` uma vez e repetir a requisição.

Os links dos e-mails apontam para `FRONTEND_URL` (`/login`, `/reset-password?token=...`).

## Estrutura

```
app/
  blueprints/        # serialização JSON
  controllers/
    concerns/        # Authenticatable (JWT), ErrorHandling, Paginatable
    api/v1/auth/     # register, login, logout, refresh, senha
    api/v1/admin/    # área admin
  mailers/           # UserMailer (boas-vindas, reset de senha)
  policies/          # Pundit
  services/auth/     # JsonWebToken, TokenIssuer, RefreshTokenRotator, TokenDenylist
spec/                # RSpec (models + requests)
```

## Produção

O `Dockerfile` (multi-stage, usuário não-root) é para produção; o `Dockerfile.dev` é usado pelo compose. Variáveis obrigatórias em produção: `DATABASE_URL`, `REDIS_URL`, `SIDEKIQ_REDIS_URL`, `RAILS_MASTER_KEY`, `JWT_SECRET`, `AR_ENCRYPTION_*`, `CORS_ORIGINS`, `FRONTEND_URL`, `APP_HOST`, `SMTP_*`, `MAILER_FROM`.
