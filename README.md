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

## Production Architecture

```
Browser ──> Nginx ──> /api/* ──> Rails (Docker)
                │                      │
                ├──> SPA               ├──> PostgreSQL (RDS)
                │                      ├──> S3 presigned URLs
                └──> S3 direct upload  └──> Lambda webhook
```

- **Compute:** Docker container on EC2 (Amazon Linux 2023)
- **Reverse proxy:** Nginx routes `/api/*` to Rails on Docker network
- **Database:** RDS PostgreSQL (db.t3.micro)
- **Storage:** S3 with presigned URLs (via `aws-sdk-s3`)
- **Processing:** Python Lambda triggered by S3 EventBridge, calls Rails webhook
- **Background jobs:** Solid Queue via database-backed jobs

## Production Environment Variables

| Variable | Description |
|---|---|
| `RAILS_MASTER_KEY` | Credentials decryption key |
| `DATABASE_URL` | PostgreSQL connection string |
| `AWS_REGION` | AWS region (e.g. us-east-1) |
| `AWS_BUCKET_NAME` | S3 bucket for uploads |
| `AWS_ACCESS_KEY_ID` | IAM credentials (or use instance profile) |
| `AWS_SECRET_ACCESS_KEY` | IAM credentials |
| `JWT_SECRET` | Token signing key |
| `CORS_ORIGINS` | Allowed frontend origins |
| `DOMAIN` | Public domain/IP for host authorization |
| `LAMBDA_WEBHOOK_SECRET` | Shared secret for Lambda → Rails webhook |
| `LAMBDA_FUNCTION_NAME` | Lambda function for file reprocessing |

## Deployment

Deployment files are in `infrastructure/` (not tracked in git):

```bash
# Requires: AWS CLI, Docker, EC2 + RDS provisioned
./infrastructure/user-data.sh   # EC2 bootstrap script
aws cloudformation deploy ...   # S3 + Lambda + EventBridge stack
```

See `docs/Project_2_Deployment_Complete.md` for full guide.
