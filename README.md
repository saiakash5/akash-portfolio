# akash-portfolio

Personal portfolio site for **Sai Akash Kuthuru** — and a working demonstration of a
multi-region, polyglot microservices platform on AWS.

The site content is the resume; the repository is the skill showcase.

## Architecture

```
                         Route 53 (failover routing)
                         /                         \
               us-east-1 (ACTIVE)            us-west-2 (DORMANT)
               ─────────────────             ──────────────────
    CloudFront ── S3  (React frontend — global, survives regional failover)
               │
              ALB ──► /api/profile/*  ──► ECS Fargate: profile-service (Spring Boot)
               │                                                        ┌─ scaled to 0
               └────► /api/contact*   ──► ECS Fargate: contact-service  │  in dormant
                                          (FastAPI)                     │  region
                                              │                         └─ (pilot light)
                              DynamoDB Global Tables
                              (automatic bi-directional replication)
```

**Active–dormant DR:** both regions get identical infrastructure from the same
Terraform modules. The dormant region runs the full network/ALB/cluster but its
ECS services are scaled to 0 tasks. Route 53 health checks the primary ALB and
fails DNS over to the secondary if it goes unhealthy; recovery is "scale the
dormant services up," not "rebuild the region."

| Component        | Tech                          | Why                                            |
| ---------------- | ----------------------------- | ---------------------------------------------- |
| Frontend         | React + Vite → S3 + CloudFront| Static, global, costs pennies                  |
| profile-service  | Java 21 / Spring Boot 3       | Serves resume/profile data as a REST API       |
| contact-service  | Python 3.12 / FastAPI         | Stores contact-form messages in DynamoDB       |
| Database         | DynamoDB Global Tables        | Serverless, multi-region replication built in  |
| Infra            | Terraform (AWS provider v5)   | Modules reused across both regions             |

## Repository layout

```
frontend/                  React + Vite single-page app
services/
  profile-service/         Spring Boot REST API  (port 8080, /api/profile)
  contact-service/         FastAPI service        (port 8001, /api/contact)
infra/                     Terraform — root config + reusable modules
  modules/network/         VPC, public subnets, security groups
  modules/alb/             ALB + path-based routing + target groups
  modules/ecs-service/     Reusable Fargate service (task def, IAM, logs)
  modules/region-stack/    One full regional backend (instantiated twice)
docker-compose.yml         Run both backend services locally
```

## Local development

Prereqs: Node 20+, JDK 21, Python 3.12, Docker.

```bash
# Frontend (http://localhost:5173 — proxies /api to the services below)
cd frontend
npm install
npm run dev

# Both backend services in containers
docker compose up --build

# …or natively:
cd services/profile-service && ./mvnw spring-boot:run        # :8080
cd services/contact-service && pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001                    # :8001
```

Smoke test:

```bash
curl http://localhost:8080/api/profile
curl -X POST http://localhost:8001/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"t@example.com","message":"Hi"}'
```

## Deploying to AWS

```bash
cd infra
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

Then build/push images to the ECR repos from the outputs, and sync the frontend:

```bash
cd frontend && npm run build
aws s3 sync dist "s3://$(terraform -chdir=../infra output -raw frontend_bucket)"
```

**Cost note:** the two-region backend (2 ALBs + Fargate + global table) runs
roughly $50–80/month even when idle. Cheap levers: destroy the secondary stack
between DR demos, or use Fargate Spot.

## Roadmap

- [ ] Register a domain and set `domain_name` in Terraform (enables Route 53 failover + HTTPS via ACM)
- [ ] GitHub Actions CI/CD: build → push to ECR → `terraform apply` → S3 sync
- [ ] Move profile data from in-memory to DynamoDB (repository interface is already in place)
- [ ] Remote Terraform state (S3 backend + state locking)
- [ ] CloudWatch alarms + a real DR-failover runbook (great interview material)
