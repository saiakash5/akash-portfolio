# akash-portfolio

A personal portfolio site for **Sai Akash Kuthuru** that doubles as a working,
end-to-end demonstration of a **fully serverless web application on AWS**,
defined entirely in Terraform, with a Cognito-secured CMS for editing content.

- **Live:** https://thesaiakash.com  (admin portal at `/admin`)
- **Repo:** https://github.com/saiakash5/akash-portfolio
- **Cost:** ~$1/month (essentially just the Route 53 hosted zone)
- **Region:** us-east-1

The résumé content lives in DynamoDB and is editable through a login-gated
portal; the public site reads it live. There are no servers, containers, or
load balancers — every component is managed and scale-to-zero.

---

## Table of contents

1. [Overview](#1-overview)
2. [Architecture at a glance](#2-architecture-at-a-glance)
3. [Tech stack](#3-tech-stack)
4. [End-to-end request flows](#4-end-to-end-request-flows)
5. [Component deep dive](#5-component-deep-dive)
6. [Data model](#6-data-model)
7. [Security model](#7-security-model)
8. [Cost breakdown](#8-cost-breakdown)
9. [Key design decisions & trade-offs](#9-key-design-decisions--trade-offs)
10. [Possible improvements / roadmap](#10-possible-improvements--roadmap)
11. [Local development](#11-local-development)
12. [Deploying](#12-deploying)
13. [Repository layout](#13-repository-layout)
14. [Interview talking points](#14-interview-talking-points)

---

## 1. Overview

The application has two planes:

- **Static plane** — a React single-page app built by Vite, stored in a private
  S3 bucket and served globally by CloudFront. This is the public website *and*
  the `/admin` portal (one SPA, two routes).
- **API plane** — an HTTP API (API Gateway) fronting three Python Lambda
  functions that read/write two DynamoDB tables. Amazon Cognito secures the
  admin routes.

Both are reached through a single domain (`thesaiakash.com`), so the browser
makes same-origin calls (`/api/...`) and there is **no CORS** anywhere.

What it demonstrates: serverless architecture, Infrastructure as Code,
authentication/authorization, least-privilege IAM, a CDN with a private origin,
NoSQL data modeling, and keyless CI/CD.

---

## 2. Architecture at a glance

```
                          ┌─────────────┐
   user ───────────────►  │  Route 53   │  thesaiakash.com / www / *.validation
                          └──────┬──────┘
                                 │ alias (A record)
                                 ▼
                        ┌──────────────────┐     TLS via ACM cert (us-east-1)
                        │    CloudFront     │
                        │  (CDN, 2 origins) │
                        └───┬───────────┬───┘
            default behavior│           │ /api/* behavior
       (cache: Optimized)   │           │ (cache: Disabled, all methods)
                            ▼           ▼
                  ┌──────────────┐   ┌─────────────────────────┐
                  │  S3 (private)│   │ API Gateway (HTTP API)  │
                  │  React build │   │  $default stage         │
                  │  via OAC     │   └───┬─────────┬───────┬───┘
                  └──────────────┘       │         │       │
                                GET /api/content    │       ANY /api/admin/{proxy+}
                                         │   POST /api/contact   │  (Cognito JWT authorizer)
                                         ▼         ▼       ▼
                                  ┌──────────┐ ┌────────┐ ┌────────┐
                                  │  read λ  │ │contact λ│ │ admin λ│   (Python 3.12)
                                  └────┬─────┘ └───┬────┘ └───┬────┘
                                       │           │          │
                          ┌────────────▼───┐   ┌───▼─────┐    │
                          │ DynamoDB        │   │DynamoDB │◄───┘
                          │ content table   │   │messages │
                          └─────────────────┘   └───┬─────┘
                                                     │
                                                ┌────▼────┐
                                                │  SNS    │──► email notification
                                                └─────────┘

   Cognito user pool + hosted login UI  ──(OAuth Code + PKCE)──►  /admin route
   GitHub Actions (OIDC, no stored keys) ──► build frontend ─► S3 sync ─► CF invalidation
   Terraform (S3 state backend) ──► provisions and owns all of the above
```

---

## 3. Tech stack

| Layer            | Technology                              | Notes                                          |
| ---------------- | --------------------------------------- | ---------------------------------------------- |
| Frontend         | React 19 + Vite 8, React Router 7       | SPA: public site + `/admin` portal             |
| Auth (client)    | `oidc-client-ts`                        | OAuth Authorization Code + PKCE                 |
| CDN / edge       | CloudFront + ACM (TLS)                  | Two origins, path-based behaviors              |
| Static hosting   | S3 (private) + Origin Access Control    | No public bucket access                         |
| API              | API Gateway **HTTP API** (v2)           | Cheaper/simpler than REST API                  |
| Compute          | AWS Lambda (Python 3.12) × 3            | read, contact, admin                           |
| Database         | DynamoDB (on-demand) × 2 tables         | `content`, `messages`                          |
| Auth (server)    | Amazon Cognito User Pool                | Hosted UI, JWT authorizer                       |
| Notifications    | Amazon SNS                              | Email on contact submission                    |
| DNS              | Route 53                                | Alias records to CloudFront                     |
| IaC              | Terraform (AWS provider v5)             | S3 state backend with native locking           |
| CI/CD            | GitHub Actions + OIDC                   | Keyless; frontend deploys                       |

---

## 4. End-to-end request flows

### 4.1 Loading the public site

1. Browser resolves `thesaiakash.com` → Route 53 alias → nearest CloudFront edge.
2. TLS handshake using the ACM certificate.
3. CloudFront serves `index.html` + hashed JS/CSS from the S3 origin (cache hit
   at the edge after the first request). S3 is private; CloudFront authenticates
   to it with **Origin Access Control** (SigV4).
4. The React app boots and calls `GET /api/content` for the live content.

### 4.2 Fetching content (`GET /api/content`)

1. `fetch("/api/content")` — relative URL, so it hits `thesaiakash.com` =
   CloudFront.
2. CloudFront matches the `/api/*` behavior → forwards to the API Gateway origin
   (caching disabled). The `AllViewerExceptHostHeader` policy lets CloudFront set
   the correct `Host` for API Gateway.
3. API Gateway matches route `GET /api/content` → invokes the **read Lambda**.
4. Read Lambda scans the `content` table, keeps items that have a `published`
   blob, sorts by `order`, returns them as JSON.
5. React renders each section by `kind` (`profile`, `experience`, `projects`,
   `skills`, `custom`). If the call fails or returns empty, components fall back
   to the static seed in `src/data/profile.js`, so the site is never blank.

### 4.3 Submitting the contact form (`POST /api/contact`)

1. The form POSTs JSON to `/api/contact` → CloudFront → API Gateway → **contact
   Lambda**.
2. The Lambda validates (`name`, valid `email`, `message`), writes an item to the
   `messages` table (`pk = MESSAGE#<uuid>`), then best-effort publishes to SNS
   (a failed notification does not fail the request — the data is already saved).
3. Returns `201`; the UI shows a success message (or, on any failure, a mailto
   fallback).

### 4.4 Admin login (Cognito, OAuth Code + PKCE)

1. At `/admin`, "Sign in" calls `userManager.signinRedirect()` → browser is sent
   to the Cognito **Hosted UI**.
2. User authenticates; Cognito redirects back to `/admin?code=...`.
3. `oidc-client-ts` exchanges the code (with the PKCE verifier) for tokens at
   Cognito's token endpoint and stores them in `localStorage`.
4. The app reads the user; the **ID token** is used as the API bearer (see
   [§9](#9-key-design-decisions--trade-offs) for why ID token, not access token).

### 4.5 Editing & publishing (`/api/admin/*`)

1. Admin calls (e.g. `PUT /api/admin/sections/{id}`) include
   `Authorization: Bearer <id_token>`.
2. CloudFront forwards the header to API Gateway, whose **Cognito JWT
   authorizer** validates the token (issuer + audience) before the request
   reaches the **admin Lambda**. Unauthorized requests are rejected at the
   gateway — the Lambda never runs.
3. The admin Lambda performs the CRUD operation on the `content` table. Edits go
   to a `draft` blob; **Publish** copies `draft` → `published` and removes the
   draft, making the change live on the next public read.

---

## 5. Component deep dive

### 5.1 Route 53 (DNS) — `certs.tf`, `frontend.tf`

- Pre-existing public hosted zone for `thesaiakash.com`. Terraform **reads** it
  with a `data` source and writes records into it.
- `thesaiakash.com` and `www` are **alias A records** pointing at the CloudFront
  distribution (alias = AWS-internal, free, supports the zone apex where a CNAME
  is illegal).
- ACM DNS-validation CNAMEs are also written here (with `allow_overwrite` because
  the zone had stale validation records from earlier iterations).

### 5.2 ACM (TLS certificate) — `certs.tf`

- One certificate for `thesaiakash.com` + `www`, **DNS-validated**.
- Must be in **us-east-1** because CloudFront only accepts certs from that region.
- Terraform creates the cert, writes the validation records, and an
  `aws_acm_certificate_validation` resource blocks until the cert is issued —
  so the apply is fully automated.

### 5.3 CloudFront (CDN / edge) — `frontend.tf`

- **Two origins:** the private S3 bucket (via OAC) and the API Gateway domain
  (custom origin, HTTPS-only).
- **Two behaviors:**
  - *default* → S3, AWS-managed **CachingOptimized** policy, GET/HEAD,
    compression on. Static assets have hashed filenames, so they cache hard.
  - `/api/*` → API Gateway, **CachingDisabled** + **AllViewerExceptHostHeader**,
    all HTTP methods (so POST/PUT/DELETE pass through). The latter policy
    forwards the `Authorization` header but strips `Host` (API Gateway needs its
    own host).
- **SPA fallback:** a custom error response maps S3 `403` → `200` `/index.html`,
  so deep links / client routes load the app instead of an error. (S3 returns
  403, not 404, for missing keys because `s3:ListBucket` is not granted.)
- **TLS:** the ACM cert with SNI; minimum TLS 1.2.
- **Price class 100** (US/EU edges) to minimize cost.

### 5.4 S3 (static hosting) — `frontend.tf`

- Private bucket; **all public access blocked**.
- A bucket policy allows `s3:GetObject` only when the request comes from this
  CloudFront distribution (`AWS:SourceArn` condition) via the **Origin Access
  Control**. The bucket is never directly reachable.

### 5.5 Frontend (React SPA) — `frontend/`

- **Entry:** `index.html` → `src/main.jsx` (React Router with `/` and `/admin`).
- **`PublicSite.jsx`** fetches `/api/content` and renders sections dynamically
  via a `kind → component` map; falls back to static seed data.
- **`Admin.jsx`** handles Cognito login state and renders a CRUD editor:
  add/edit/delete sections, edit existing résumé content, set `order` (reorder),
  save as **draft**, and **publish**. Section data is edited as JSON today
  (simple and kind-agnostic).
- **`auth.js`** wraps `oidc-client-ts` (login, logout, token retrieval, redirect
  callback). **`api.js`** centralizes fetch calls and attaches the bearer token
  for admin requests.
- **`config.js`** holds the (public) Cognito IDs and region.
- **Build:** Vite outputs hashed assets to `dist/`; `public/` (incl. `resume.pdf`)
  is copied as-is. The dev server proxies `/api/*` to the deployed API Gateway,
  so local dev exercises the real backend.

### 5.6 API Gateway (HTTP API) — `content.tf`

- **HTTP API (v2)** — chosen over REST API for lower cost and latency and a
  built-in JWT authorizer; this app doesn't need REST API features (API keys,
  request/response transforms, WAF-per-stage).
- Routes:
  - `GET /api/content` → read Lambda (public)
  - `POST /api/contact` → contact Lambda (public)
  - `ANY /api/admin/{proxy+}` → admin Lambda (**JWT authorizer**)
- **JWT authorizer:** `issuer = https://cognito-idp.us-east-1.amazonaws.com/<poolId>`,
  `audience = <app client id>`. Validates the token signature, expiry, issuer,
  and audience before invoking the Lambda.
- `$default` stage with auto-deploy. Lambda integrations use payload format 2.0.
- `aws_lambda_permission` grants API Gateway permission to invoke each function.

### 5.7 Lambda functions — `services/`, `content.tf`

All Python 3.12, packaged by Terraform's `archive_file` (zip), with
`source_code_hash` so a code change redeploys on `terraform apply`.

- **read** (`services/content-api/read`) — public. `Scan` with a filter for
  items that have `published`, sort by `order`, return JSON (`default=str`
  handles DynamoDB `Decimal`).
- **admin** (`services/content-api/admin`) — Cognito-protected (auth happens at
  the gateway). Routes by method + path; CRUD with reserved-word aliasing
  (`order`, `data`, etc.); publish = `SET published REMOVE draft`.
- **contact** (`services/contact-fn`) — public. Validates input, `PutItem` to
  `messages`, best-effort `SNS publish`.

### 5.8 DynamoDB — `main.tf`, `content.tf`

- **`content` table** — partition key `pk` only; one item per section. On-demand
  billing (`PAY_PER_REQUEST`). Schemaless beyond the key — each item carries
  `kind`, `title`, `order`, and `published` / `draft` blobs.
- **`messages` table** — partition key `pk` (`MESSAGE#<uuid>`); stores contact
  submissions. Streams remain enabled (a historical constraint from removing a
  global-table replica; harmless).
- No SQL, no schema migrations, no connection pool. Lambdas authenticate with
  their IAM role (temporary credentials) — no connection string or password.

### 5.9 Cognito (auth) — `content.tf`

- **User pool** with `admin_create_user_only` (no public sign-up — you create
  users) and a 12-char password policy.
- **App client** is a public SPA client (no secret), using **Authorization Code
  + PKCE** with scopes `openid email profile`; callback/logout URLs for prod and
  localhost.
- **Hosted UI domain** provides the login page (no custom login code to own).
- One admin user is created by Terraform; Cognito emails a temporary password,
  and first login forces a permanent one.

### 5.10 SNS (notifications) — `notifications.tf`

- A topic with an email subscription (requires a one-time confirm click). The
  contact Lambda publishes a formatted message on each submission. Also defines
  a monthly AWS **Budget** alert as a cost guardrail.

### 5.11 IAM (security model) — across all files

- **Per-function roles, least privilege:** the content lambdas' role grants only
  the `content` table actions it needs; the contact lambda's role grants only
  `dynamodb:PutItem` on `messages` and `sns:Publish` on the one topic. Each role
  also has the basic Lambda logging policy.
- **No long-lived credentials** anywhere. Lambdas use their execution role; the
  browser uses Cognito tokens; CI uses GitHub OIDC (below).

### 5.12 Terraform (IaC) — `infra/`

- **Flat file layout** (no modules now that it's single-environment serverless):
  `main.tf` (providers, state, messages table), `content.tf` (DynamoDB, Cognito,
  Lambdas, API Gateway), `frontend.tf` (S3, CloudFront, DNS), `certs.tf`,
  `notifications.tf`, `cicd.tf`.
- **Remote state** in an S3 bucket with **native S3 locking** (`use_lockfile`,
  no DynamoDB lock table needed). State maps resource addresses ↔ real AWS IDs,
  so the whole stack can be destroyed and recreated from any machine.
- **Lambda code ships with `terraform apply`** (via `archive_file` +
  `source_code_hash`) — there is no separate Lambda deploy step.

### 5.13 GitHub Actions (CI/CD) — `.github/workflows/deploy.yml`, `cicd.tf`

- **Keyless auth via OIDC:** the workflow requests a short-lived OIDC token from
  GitHub; an IAM OIDC provider + role trust policy (scoped to this repo) lets it
  `AssumeRoleWithWebIdentity`. No AWS keys are stored in GitHub.
- **Frontend-only pipeline:** on push to `main` (paths `frontend/**`), it builds
  the SPA, syncs to S3, and invalidates CloudFront. Backend/infra changes go out
  via `terraform apply` (Lambda code included).
- The deploy role is least-privilege: S3 to the one bucket + CloudFront
  invalidation only.

---

## 6. Data model

The `content` table holds **one item per section**:

| Field        | Type   | Purpose                                                     |
| ------------ | ------ | ---------------------------------------------------------- |
| `pk`         | string | `SECTION#<id>` (e.g. `SECTION#profile`, `SECTION#<uuid>`)  |
| `kind`       | string | `profile` \| `experience` \| `projects` \| `skills` \| `custom` |
| `title`      | string | Display heading                                            |
| `order`      | number | Sort position on the public site (enables reordering)      |
| `published`  | map    | The **live** content blob (absent until first publish)    |
| `draft`      | map    | **Unpublished** edits (absent when nothing pending)        |
| `updatedAt`  | number | Epoch seconds                                             |

- **Public read** returns only items that have `published`, using `published`.
- **Admin** edits `draft`; **publish** promotes `draft` → `published`.
- The `data` blob shape varies by `kind` (e.g. `experience` → `{ items: [...] }`,
  `custom` → `{ body, tags, links }`), which the frontend renders per kind.

The `messages` table is a simple append log: `pk = MESSAGE#<uuid>` plus `name`,
`email`, `message`, `received_at`.

---

## 7. Security model

- **HTTPS everywhere** — CloudFront redirects to HTTPS; API Gateway and Cognito
  are HTTPS-only.
- **Private origin** — S3 is not publicly reachable; only CloudFront (via OAC)
  can read it.
- **Authentication** — Cognito Hosted UI with Authorization Code + PKCE (no
  client secret in the browser; the code is useless without the PKCE verifier).
- **Authorization** — API Gateway's Cognito **JWT authorizer** gates every
  `/api/admin/*` route; the admin Lambda only runs for valid tokens. Public
  read/contact routes are intentionally open.
- **Least-privilege IAM** — scoped roles per Lambda; CI role limited to S3 +
  CloudFront; no wildcards on data resources.
- **No secrets in the repo** — Cognito client/pool IDs are public by design for
  SPA clients; everything else is an IAM-derived temporary credential.
- **Known gap** — there is currently **no rate limiting / WAF** on the public
  endpoints (removed to minimize cost). See improvements.

---

## 8. Cost breakdown

At portfolio traffic, effectively **~$1/month**:

| Service       | Cost driver                  | Effective cost |
| ------------- | ---------------------------- | -------------- |
| Route 53      | Hosted zone                  | ~$0.50/mo      |
| CloudFront    | Requests + transfer          | ~$0 (free-tier-ish) |
| S3            | A few hundred KB             | ~$0            |
| Lambda        | Per-invocation               | ~$0            |
| DynamoDB      | On-demand, tiny volume       | ~$0            |
| API Gateway   | Per-request (HTTP API)       | ~$0            |
| Cognito       | Free tier (well under 50k MAU)| $0            |
| SNS           | A handful of emails          | ~$0            |

The earlier ECS/Fargate + ALB iteration cost ~$20–80/month; going serverless cut
that by ~95%.

---

## 9. Key design decisions & trade-offs

**Serverless over ECS/Fargate.** The project started as Spring Boot + FastAPI on
ECS Fargate behind an ALB, multi-region with DR. That's a great showcase but
costs ~$20+/mo (the ALB alone is ~$16) and needs operating. For a low-traffic
portfolio, Lambda + API Gateway is ~$0, scale-to-zero, and nothing to patch. The
trade-off: cold starts (sub-second for Python) and per-request limits vs. always-
warm containers — irrelevant here. *(The ECS version is preserved in git history.)*

**DynamoDB over RDS/Aurora.** No relational joins are needed — content is fetched
as whole sections. DynamoDB is serverless, on-demand, and has no idle cost; RDS
has an always-on instance. Trade-off: no ad-hoc queries / joins, and you model
access patterns up front.

**Same-origin API via CloudFront (no CORS).** The browser calls `/api/*` on the
site's own domain; CloudFront routes it to API Gateway. Because it's same-origin,
there are **zero CORS headers/preflights** to manage. Also means one WAF/edge
config could cover both site and API.

**ID token (not access token) as the API bearer.** API Gateway's HTTP API JWT
authorizer validates the `aud` claim. Cognito **access tokens don't carry `aud`**
(they have `client_id`); **ID tokens do**. So the client sends the ID token,
which the authorizer can validate against the app client ID. (Common Cognito +
HTTP API gotcha.)

**Item-per-section content model with draft/published blobs.** Keeps reads to a
single small scan and makes draft/publish and reordering trivial (a field copy
and an `order` number). Trade-off: `Scan` doesn't scale to thousands of items —
fine for a portfolio, would become a GSI/query at scale.

**Terraform `count` vs apply-time values.** Several toggles (in the older ECS
modules) used static boolean flags next to the actual ARNs because `count` must
be known at *plan* time and can't depend on a value only known after apply.

**WAF removed for cost.** WAF on CloudFront is ~$5–6/mo — the single largest line
item once ECS was gone. Removed it to hit ~$1/mo, accepting no managed rate
limiting on public endpoints. Mitigations remain (input validation, pay-per-
request economics); re-adding it is one revert away.

**Lambda code via Terraform, not CI.** Backend deploys happen with
`terraform apply` (infra + code together) so state and code never drift; CI only
ships the frontend. Trade-off: backend deploys are manual/local today.

---

## 10. Possible improvements / roadmap

**Security & abuse resistance**
- Re-add **AWS WAF** (rate-based rule + managed rule sets) or API Gateway
  throttling / usage plans on the public endpoints.
- Add a **honeypot field or CAPTCHA** to the contact form to deter bots.
- Enable **Cognito advanced security** + **MFA** for the admin user.
- Enable **DynamoDB Point-in-Time Recovery (PITR)** on both tables (backups).

**Data & API**
- Split the shared content-Lambda IAM role so the **read Lambda is read-only**
  (currently it can write).
- Replace the read **`Scan` with a GSI/query** (e.g. partition on a constant +
  sort on `order`) or cache the assembled payload — avoids full-table scans as
  content grows.
- Add **optimistic concurrency** (conditional writes / version attribute) so two
  edits can't silently clobber each other.

**Performance**
- **Cache `/api/content` at CloudFront** (short TTL) and trigger an invalidation
  on publish — fewer Lambda invocations, lower latency. (Today it's
  cache-disabled for simplicity.)
- Consider **provisioned concurrency** only if cold starts ever matter
  (they don't at this scale).

**Frontend / UX**
- Replace the admin **JSON editor with per-kind forms** (typed fields, markdown,
  validation) and **image uploads to S3**.
- **SEO/SSR:** the site is client-rendered, so content isn't in the initial HTML
  (weak for crawlers/social previews). Move to **SSG/SSR (e.g. Next.js)** or
  prerender/bake content at build time; make OG tags dynamic.
- Accessibility audit (keyboard nav, ARIA, contrast).
- **Custom domain for the Cognito Hosted UI** (`auth.thesaiakash.com`) or a fully
  custom login form for branding.

**Observability & quality**
- **CloudWatch dashboards + alarms** (Lambda errors/throttles, 5xx), **X-Ray**
  tracing, structured JSON logging, explicit log retention.
- **Tests:** Lambda unit tests (pytest + `moto`), frontend tests (Vitest +
  Testing Library), and `terraform validate` / `tflint` / `checkov` in CI.

**Delivery & ops**
- Publish the S3 bucket name and CloudFront distribution ID to **SSM Parameter
  Store** and have CI read them — removes the hardcoded IDs in `deploy.yml` (the
  one thing that breaks on a destroy/recreate). *(Top backlog item.)*
- Run **Terraform from CI** (plan on PR, apply on merge) with environment
  separation (dev/prod via workspaces).
- Move contact notifications from SNS email to **SES** (templated mail) or a
  small admin inbox view.

---

## 11. Local development

Prereqs: Node 20+, Python 3.12 (only needed for the seed script).

```bash
cd frontend
npm install
npm run dev     # http://localhost:5173
```

The Vite dev server proxies `/api/*` to the deployed API Gateway, so live content
and the contact form work locally without running any backend.

---

## 12. Deploying

```bash
cd infra
terraform init
terraform apply                      # provisions everything; Lambda code included
python ../scripts/seed_content.py    # one-time: seed content from the résumé data
```

- **Frontend** auto-deploys via GitHub Actions on push to `main` (build → S3 sync
  → CloudFront invalidation), authenticated with GitHub OIDC.
- **Backend/infra** changes deploy with `terraform apply`.
- **Content** is edited live at `/admin`, or in bulk via
  `python scripts/seed_content.py --force` (overwrites all sections).

> Note: `deploy.yml` currently hardcodes the S3 bucket and CloudFront
> distribution ID; both change if the stack is destroyed and recreated. Updating
> them from `terraform output` (or wiring SSM) is the top open item.

---

## 13. Repository layout

```
frontend/                     React SPA (public site + /admin portal)
  src/PublicSite.jsx          fetches /api/content, renders sections by kind
  src/Admin.jsx               Cognito-gated content editor (CRUD, draft/publish)
  src/auth.js  src/api.js     Cognito (PKCE) + API helpers
  src/config.js               public Cognito/region config
  src/components/             Hero, Experience, Projects, Skills, CustomSection, …
  src/data/profile.js         static seed / fallback content
services/
  content-api/read/           public content read Lambda
  content-api/admin/          admin CRUD Lambda (draft/publish, reorder)
  contact-fn/                 contact form Lambda
infra/                        Terraform (flat, no modules)
  main.tf                     providers, S3 state backend, messages table
  content.tf                  DynamoDB, Cognito, Lambdas, API Gateway
  frontend.tf                 S3, CloudFront, OAC, DNS records
  certs.tf  notifications.tf  cicd.tf
scripts/seed_content.py       seed DynamoDB from the résumé data
.github/workflows/deploy.yml  frontend CI/CD (OIDC)
```

---

## 14. Interview talking points

Likely questions, with crisp answers, per component:

**"Walk me through what happens when someone submits the contact form."**
Browser POSTs `/api/contact` (same-origin) → CloudFront `/api/*` behavior →
API Gateway route `POST /api/contact` → contact Lambda validates, `PutItem` to
DynamoDB, best-effort SNS publish → 201. No servers involved; scales to zero.

**"How is the admin area secured?"**
Cognito Hosted UI (Authorization Code + PKCE, no client secret in the browser).
The ID token is sent as a bearer; API Gateway's JWT authorizer validates
signature/issuer/audience before the admin Lambda runs. IAM is least-privilege.

**"Why DynamoDB and not a relational DB?"**
Access pattern is "fetch whole sections" — no joins. DynamoDB is serverless,
on-demand, zero idle cost. RDS would add an always-on instance. The cost is
up-front access-pattern modeling and no ad-hoc queries.

**"Why is there no CORS configuration?"**
The API is served same-origin through CloudFront (`/api/*` on the site domain),
so the browser never makes a cross-origin request.

**"How does CI deploy without AWS keys?"**
GitHub OIDC: the workflow gets a short-lived token, assumes a scoped IAM role via
web identity federation. Nothing long-lived is stored.

**"What would you improve / what are the weaknesses?"**
No rate limiting after WAF removal; read path uses `Scan`; shared read/write
Lambda role; client-rendered (SEO); hardcoded deploy IDs; no automated tests or
alarms. (See [§10](#10-possible-improvements--roadmap) — knowing your system's
gaps is the point.)

**"How do you handle drafts vs. live content?"**
Each section item has separate `draft` and `published` blobs; public reads only
return `published`; publishing copies `draft` → `published`. Simple, atomic per
item.

**"Cold starts?"**
Python Lambda cold start is sub-second and only on the first call after idle;
acceptable for this traffic. Provisioned concurrency is the lever if it mattered.

---

*Built and operated end to end — frontend, backend, data, infrastructure, CI/CD —
as a single-author project. The git history also contains an earlier multi-region
ECS/Fargate + Spring Boot + FastAPI iteration, retired in favor of this
serverless design.*
