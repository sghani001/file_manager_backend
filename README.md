# CloudVault Backend

Rails 8.1 API-only backend for the CloudVault file management platform. Handles file uploads, AI-powered processing, secure shareable links, and a RAG-style AI chat assistant.

## Stack

- **Rails 8.1.3** (API mode) + **Ruby 3.3.11**
- **PostgreSQL** — primary database, cache, queue, and cable
- **Solid Queue** — database-backed background jobs
- **JWT** + **bcrypt** — authentication
- **Kamal** — Docker-based deployment
- **Thruster** — asset caching/compression

## Quick Start

```bash
# Install dependencies
bundle install

# Set up database
rails db:create db:migrate db:seed

# Start server
bin/dev
```

Server runs on `http://localhost:3000`.

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `JWT_SECRET` | Yes | Secret key for JWT token signing |
| `RAILS_MASTER_KEY` | Yes | Rails credentials decryption key |
| `BACKEND_DATABASE_PASSWORD` | Yes | PostgreSQL production password |
| `RAILS_LOG_LEVEL` | No | Log level (default: `info`) |

## Key Endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/signup` | Create account |
| POST | `/api/v1/login` | Authenticate |
| GET | `/api/v1/profile` | Current user info |
| POST | `/api/v1/files/presigned_url` | Initiate file upload |
| POST | `/api/v1/files/:id/mark_uploaded` | Confirm upload, trigger processing |
| GET | `/api/v1/files` | List user's files |
| POST | `/api/v1/chat` | AI chat (global or per-file) |
| POST | `/api/v1/share_links` | Create share link |
| GET | `/api/v1/shares/:token` | Access shared file |

## Testing

```bash
rails test
bin/brakeman         # Security scan
bin/bundler-audit    # Dependency audit
bin/rubocop          # Lint
```

## Deployment

```bash
bin/kamal setup      # First-time server provision
bin/kamal deploy     # Deploy application
```
