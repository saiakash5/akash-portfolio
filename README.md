# akash-portfolio

Personal portfolio site for **Sai Akash Kuthuru** — and a working demonstration
of a fully serverless web platform on AWS, defined end to end in Terraform.

The site content lives in DynamoDB and is editable through a Cognito-secured
admin portal; the repository is the skill showcase.

## Architecture

```
                         Route 53
                   thesaiakash.com → CloudFront
                            │
                       CloudFront
                   │                          │
         default behavior              /api/* behavior
                   │                          │
                  S3                    API Gateway (HTTP API)
            (React SPA build)          ├─ GET  /api/content  → read Lambda   ─┐
                                       ├─ POST /api/contact  → contact Lambda ─┤
                                       └─ ANY  /api/admin/*  → admin Lambda   ─┤
                                          (Cognito JWT authorizer)            │
                                                                              ▼
                                       Cognito  ──login──►  /admin       DynamoDB
                                       (admin portal)                    (content + messages)
                                                                              │
                                                          contact Lambda → SNS → email
```

Everything is **serverless and scale-to-zero** — no servers to keep awake, the
contact form works 24/7, and idle cost is a few dollars a month.

| Component       | Tech                            | Role                                         |
| --------------- | ------------------------------- | -------------------------------------------- |
| Frontend        | React + Vite → S3 + CloudFront  | Public site + `/admin` portal (one SPA)      |
| Content read    | Python Lambda + API Gateway     | Serves published sections to the public site |
| Admin CRUD      | Python Lambda (Cognito JWT)     | Add/edit/delete sections, draft → publish    |
| Contact form    | Python Lambda                   | Validates → DynamoDB → SNS email             |
| Database        | DynamoDB (content + messages)   | Schemaless, pay-per-request                  |
| Auth            | Amazon Cognito                  | Admin login (OAuth Code + PKCE)              |
| Edge            | CloudFront + ACM                | TLS, caching, global delivery                |
| Infra / CI      | Terraform + GitHub Actions OIDC | One `apply`; keyless frontend deploys        |

## Content model

One DynamoDB item per section (`profile`, `experience`, `projects`, `skills`,
or custom like `hobbies`), each with an `order`, a `published` blob, and a
`draft` blob. The public read Lambda returns only `published` sections; the
admin portal edits `draft` and copies it to `published` on publish.

## Repository layout

```
frontend/                     React SPA — public site + /admin portal
  src/PublicSite.jsx          fetches /api/content, renders sections by kind
  src/Admin.jsx               Cognito-gated content editor
  src/data/profile.js         static seed / fallback content
services/
  content-api/read/           public content read Lambda
  content-api/admin/          admin CRUD Lambda (draft/publish, reorder)
  contact-fn/                 contact form Lambda
infra/                        Terraform (single file set, no modules)
  main.tf                     providers, state backend, messages table
  content.tf                  DynamoDB, Cognito, Lambdas, API Gateway
  frontend.tf                 S3, CloudFront, DNS records
  certs.tf  waf.tf  notifications.tf  cicd.tf
scripts/seed_content.py       seed DynamoDB from the static resume data
```

## Local development

Prereqs: Node 20+, Python 3.12.

```bash
cd frontend
npm install
npm run dev   # http://localhost:5173 — proxies /api/* to API Gateway
```

The dev server proxies `/api/*` to the deployed API Gateway, so the live
content and contact endpoints work locally without running anything else.

## Deploying

```bash
cd infra
terraform init
terraform apply          # provisions everything; Lambda code ships with apply
python ../scripts/seed_content.py   # one-time content seed
```

Frontend changes auto-deploy via GitHub Actions on push to `main` (build →
S3 sync → CloudFront invalidation), authenticated with GitHub OIDC — no AWS
keys stored in the repo.

## Editing content

- **Portal:** sign in at `/admin` (Cognito), edit sections, publish — changes
  are live immediately.
- **Bulk/seed:** edit `scripts/seed_content.py` and run it with `--force`.

## Notes

- Cost is roughly **$1/month** (just the Route 53 hosted zone; Lambda,
  DynamoDB, API Gateway, Cognito, and CloudFront are all near-zero at
  portfolio traffic).
- The git history contains an earlier multi-region ECS/Fargate + Spring Boot +
  FastAPI iteration, retired in favor of this serverless design.
