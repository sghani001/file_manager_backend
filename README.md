<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0A071B,50:1A1235,100:635BFF&height=200&section=header&text=CloudVault%20Backend&fontSize=48&fontColor=ffffff&fontAlignY=38&desc=Rails%208.1%20API%20%C2%B7%20S3%20Ingestion%20%C2%B7%20Lambda%20Pipeline&descSize=18&descAlignY=58&descColor=635BFF" width="100%" />

<br/>

[![Rails Version](https://img.shields.io/badge/Rails-8.1.3-CC0000?style=for-the-badge&logo=ruby-on-rails&logoColor=white)](https://rubyonrails.org/)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.3.11-CC0000?style=for-the-badge&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Database](https://img.shields.io/badge/PostgreSQL-Active-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Security](https://img.shields.io/badge/Brakeman-Verified-success?style=for-the-badge&logo=shield&logoColor=white)](https://brakemanscanner.org/)

<br/>

> *A file management API backend featuring decoupled S3 pipelines, automated Lambda event hooks, and secure share links.*

</div>

---

## 🖥️ App Demonstration

<video src="https://github.com/user-attachments/assets/6af1af46-187b-4684-bff1-f42f230711b7" autoplay loop muted playsinline width="100%" style="border-radius: 8px; border: 1px solid #1A1235; max-height: 500px; object-fit: cover;"></video>

---

## 🛠️ Tech Stack

| Layer | Technology | Role |
| :--- | :--- | :--- |
| **Backend Framework** | `Ruby on Rails 8.1.3` *(API Mode)* | REST API layer |
| **Runtime** | `Ruby 3.3.11` | CRuby runtime |
| **Database** | `PostgreSQL` | Primary storage |
| **Background Queue** | `Solid Queue` | Database-backed job distribution |
| **Authentication** | `JWT` + `bcrypt` | Stateless token auth |
| **Deployment** | `Docker` + `CloudFormation` | EC2 container deployment |
| **Object Storage** | `AWS S3` | File storage with presigned URLs |
| **Serverless** | `AWS Lambda` (Python 3.11) | EventBridge-triggered file processing |

---

## ✨ System Features

### 📁 Direct S3 Ingestion
* **Presigned Uploads:** Generates scoped S3 URLs via `/api/v1/files/presigned_url` so files stream directly to S3, bypassing the app server.
* **State Tracking:** Files move through `uploading` → `processing` → `processed` states. Clients call `/mark_uploaded` after upload completes.

### 🤖 Lambda Processing Pipeline
* **EventBridge Trigger:** S3 `Object Created` events automatically invoke a Python Lambda function via EventBridge rule.
* **Secured Webhook:** Lambda POSTs processing results to `/api/v1/processing/webhook` authenticated with a shared `LAMBDA_WEBHOOK_SECRET` header.

### 🔗 Share Links
* **Token-based Sharing:** Generate time-limited share links with optional passcode via `/api/v1/share_links`.
* **Public Access:** Shared files are accessible via `/api/v1/shares/:token` without login.

---

## 🛰️ API Endpoints

All under `/api/v1/`:

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/signup` | Public | Create account |
| `POST` | `/login` | Public | Get JWT token |
| `GET` | `/profile` | Bearer | Current user info |
| `POST` | `/files/presigned_url` | Bearer | Get S3 presigned upload URL |
| `POST` | `/files/:id/mark_uploaded` | Bearer | Mark file as uploaded → sets status to processing |
| `GET` | `/files/:id/download` | Bearer | Redirect to S3 presigned download URL |
| `POST` | `/files/:id/reprocess` | Bearer | Re-invoke Lambda for a file |
| `GET` | `/files` | Bearer | List user's files |
| `POST` | `/processing/webhook` | Shared secret | Lambda callback (no Bearer) |
| `POST` | `/share_links` | Bearer | Create share link |
| `GET` | `/shares/:token` | Public | Access shared file |
| `POST` | `/shares/:token/validate` | Public | Validate share passcode |

---

## 🏗️ Production Architecture

```
Browser ──> Nginx ──> /api/* ──> Rails (Docker)
│                     │
├──> React SPA         ├──> PostgreSQL (RDS)
│                     ├──> S3 presigned URLs
└──> S3 direct upload  └──> Lambda webhook
```

* **Compute:** Docker containers on EC2 (Amazon Linux 2023) with nginx reverse proxy routing `/api/` to the Rails container.
* **Storage:** Files stored in S3 with all public access blocked; access only via presigned URLs (1-hour expiry).
* **Processing:** S3 EventBridge → Lambda (Python 3.11) → webhook POST back to Rails.

---

## ⚙️ Environment Variables

| Variable | Required | Purpose |
| :--- | :--- | :--- |
| `JWT_SECRET` | Yes | Token signing secret |
| `RAILS_MASTER_KEY` | Yes | Credentials decryption key |
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `AWS_REGION` | Yes | AWS region (e.g. us-east-1) |
| `AWS_BUCKET_NAME` | Yes | S3 bucket for file storage |
| `LAMBDA_WEBHOOK_SECRET` | Yes | Shared secret for Lambda webhook auth |
| `CORS_ORIGINS` | No | Allowed CORS origins |

---

## 🚀 Getting Started

```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start dev server
bin/dev
```

Local endpoint: `http://localhost:3000`

### Testing

```bash
rails test          # Unit and integration tests
bin/brakeman        # Security audit
bin/bundler-audit   # Dependency CVE check
bin/rubocop         # Linting
```

---

## 📦 Deployment

Infrastructure is defined in `infrastructure/cloudvault-full-stack.yaml` (CloudFormation). It provisions:

- VPC with public subnets, IGW, route tables
- EC2 instance (t3.medium, Docker, nginx proxy)
- RDS PostgreSQL
- S3 bucket (public access blocked, CORS configured)
- Lambda function (Python 3.11, EventBridge-triggered)
- EventBridge rule for S3 `Object Created` events
- Lambda Function URL (for testing)

```bash
aws cloudformation deploy --template-file infrastructure/cloudvault-full-stack.yaml --stack-name cloudvault --capabilities CAPABILITY_IAM
```

---

### Built with ⚡ by [Syed Ghani](https://github.com/sghani001)
