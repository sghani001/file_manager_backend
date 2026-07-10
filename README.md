<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0A071B,50:1A1235,100:635BFF&height=200&section=header&text=CloudVault%20Backend&fontSize=48&fontColor=ffffff&fontAlignY=38&desc=Production-Ready%20Rails%208.1%20API%20%C2%B7%20RAG%20AI%20Engine&descSize=18&descAlignY=58&descColor=635BFF" width="100%" />

<br/>

[![Rails Version](https://img.shields.io/badge/Rails-8.1.3-CC0000?style=for-the-badge&logo=ruby-on-rails&logoColor=white)](https://rubyonrails.org/)
[![Ruby Version](https://img.shields.io/badge/Ruby-3.3.11-CC0000?style=for-the-badge&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Database](https://img.shields.io/badge/PostgreSQL-Active-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Security](https://img.shields.io/badge/Brakeman-Verified-success?style=for-the-badge&logo=shield&logoColor=white)](https://brakemanscanner.org/)

<br/>

> *An enterprise-grade, API-only file management backend featuring decoupled S3 pipelines, automated lambda event hooks, and a real-time RAG-style AI chat agent.*

</div>

---

## 🖥️ App Demonstration

<video src="https://github.com/user-attachments/assets/6af1af46-187b-4684-bff1-f42f230711b7" autoplay loop muted playsinline width="100%" style="border-radius: 8px; border: 1px solid #1A1235; max-height: 500px; object-fit: cover;"></video>

---

## 🛠️ Tech Stack & Core Engine

The engine is engineered around the minimalist Rails 8 API blueprint, substituting memory-heavy cache layers with optimized relational storage configurations.

| Layer | Technology | Role |
| :--- | :--- | :--- |
| **Backend Framework** | `Ruby on Rails 8.1.3` *(API Mode)* | Secured MVC REST API Layer |
| **Runtime Environment**| `Ruby 3.3.11` | Optimized CRuby concurrency garbage collection |
| **Database Engines** | `PostgreSQL` | Primary entity storage, cache pools, and web-sockets |
| **Background Queue** | `Solid Queue` | Multi-threaded database-backed job distribution |
| **Authentication System**| `JWT` + `bcrypt` | Stateless cryptographic token claims architecture |
| **Deployment & Proxies**| `Kamal` + `Thruster` + `Docker` | Multi-stage orchestration & transparent asset proxying |

---

## ✨ System Features

### 📁 Scalable Direct S3 Ingestion
* **Presigned Handshakes:** Generates scoped cryptographic target endpoints via `/api/v1/files/presigned_url` to entirely offload data streams from the application layer.
* **State Verification:** State machines process structural files after the client fires a distinct structural `/mark_uploaded` completion hook.

### 🤖 Decoupled AI Pipeline & RAG Chat
* **EventBridge Processing:** Python AWS Lambda workflows automatically intercept S3 events to handle binary extractions.
* **Secured Inbound Webhooks:** State transformations map safely back to database structures utilizing high-entropy `LAMBDA_WEBHOOK_SECRET` tokens.
* **Contextual Agent Chat:** Context-aware endpoint (`/api/v1/chat`) provides global or file-isolated RAG assistant execution models.

---

## 🛰️ Key API Directory

All transactional integrations route strictly through the versioned `/api/v1/` namespace:

| Action | Path | Authentication | Intended Operational Domain |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/signup` | Public | Registers a new actor tenant into bcrypt hashing schemas. |
| `POST` | `/api/v1/login` | Public | Validates user identity and signs state claims into JWT payloads. |
| `GET` | `/api/v1/profile` | **Bearer Token** | Serializes isolated profile states for the active user session. |
| `POST` | `/api/v1/files/presigned_url` | **Bearer Token** | Requests secure direct-to-S3 storage tokens. |
| `POST` | `/api/v1/files/:id/mark_uploaded`| **Bearer Token** | Changes file state and kicks off async background workers. |
| `GET` | `/api/v1/files` | **Bearer Token** | Returns user-owned active resource trees. |
| `POST` | `/api/v1/chat` | **Bearer Token** | Dispatches a context-driven prompt to the internal RAG system. |
| `POST` | `/api/v1/share_links` | **Bearer Token** | Packages localized secure sharing assets with access tokens. |
| `GET` | `/api/v1/shares/:token` | Public | Decrypts single-use asset tokens without standard user login. |

---

## 🏗️ Production Architecture


```

Browser ──> Nginx ──> /api/* ──> Rails (Docker)
│                     │
├──> SPA              ├──> PostgreSQL (RDS)
│                     ├──> S3 presigned URLs
└──> S3 direct upload └──> Lambda webhook

```

* **Target Compute Layer:** Optimized Docker-packaged images riding on Amazon Linux 2023 EC2 topologies.
* **Gateway Boundaries:** Internal Docker networks mapping traffic dynamically via strict reverse Nginx patterns.
* **Object Store Mapping:** Decoupled storage models interfacing across the official `aws-sdk-s3` compilation stack.

---

## ⚙️ Environment Variables & Manifest Configurations

### Development & Sandbox Core
| Primitive Key | Required | System Boundary Scope |
| :--- | :--- | :--- |
| `JWT_SECRET` | **Yes** | Symmetric token compilation secret. |
| `RAILS_MASTER_KEY` | **Yes** | Standard environmental encryption key framework wrapper. |
| `BACKEND_DATABASE_PASSWORD` | **Yes** | Production PostgreSQL infrastructure credentials block. |
| `RAILS_LOG_LEVEL` | No | Operational output constraints (defaults cleanly to `info`). |

### Staging & Production Overrides
| Primitive Key | System Boundary Scope |
| :--- | :--- |
| `DATABASE_URL` | Explicit connection pool formatting targets for AWS RDS engine. |
| `AWS_REGION` / `AWS_BUCKET_NAME` | Targeted global cloud computing asset footprints. |
| `AWS_ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` | Dedicated IAM scope constraints (or mapped natively through EC2 Profiles). |
| `CORS_ORIGINS` | Strict domain parsing arrays controlling cross-origin interface calls. |
| `LAMBDA_WEBHOOK_SECRET` | Cryptographic parameter securing inbound automated worker responses. |

---

## 🚀 Getting Started

### Local Workspace Bootstrapping
```bash
# Pull framework gems and dependencies
bundle install

# Run structural relational migrations and seed default environments
rails db:create db:migrate db:seed

# Spin up localized process monitoring boundaries
bin/dev

```

*Local endpoint binds to `http://localhost:3000` executing out-of-the-box configuration properties.*

### Verification Suite & Audits

Ensure complete pipeline continuous integration compliance before pushing changes downstream:

```bash
rails test          # Unit and integration assertions
bin/brakeman        # Security vulnerability and injection checks
bin/bundler-audit   # Active dependency CVE checks
bin/rubocop         # Structural layout styling constraints enforcement

```

---

## 📦 Deployment Protocols

Infrastructure definitions are segmented directly away from application code paths within the `infrastructure/` directory (untracked in version control).

```bash
# Provision systemic operating scripts to bootstrap targets
./infrastructure/user-data.sh

# Deploy core S3 buckets, EventBridge streams, and Lambda parameters via CloudFormation
aws cloudformation deploy --template-file infrastructure/cloudformation.yml --stack-name cloudvault-core

```

*Operational procedures, pipeline mechanics, and maintenance rules are maintained within `docs/Project_2_Deployment_Complete.md`.*

---

### Built with ⚡ by [Syed Ghani](https://github.com/sghani001)
