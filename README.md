# phantom-link

A production-style URL shortener built on AWS. Accepts a long URL, returns an 8-character short link, tracks clicks via an event-driven pipeline, and serves everything through a custom domain with HTTPS.

Live at [ghostlink.lol](https://ghostlink.lol)

---

## Architecture

```
Browser
  |
  |-- POST /create --------> API Gateway HTTP API
  |                                |
  |                                v
  |                         Lambda (Python 3.12)
  |                                |
  |                                v
  |                         RDS Proxy --> RDS Postgres
  |
  |-- GET /{code}/stats ----> API Gateway HTTP API
  |                                |
  |                                v
  |                         Lambda --> Postgres + DynamoDB
  |
  |-- GET /{code} ----------> CloudFront --> WAF WebACL
                                   |
                          .--------+--------.
                          |                 |
                     path = /          path = /{code}
                          |                 |
                          v                 v
                      S3 Bucket           ALB
                    (frontend)             |
                                           v
                                    ECS Fargate (FastAPI)
                                           |
                              .------------+------------.
                              |                         |
                              v                         v
                        RDS Proxy                S3 click event
                        (lookup)               clicks/{code}/{ts}.json
                              |                         |
                              v                         v
                         302 redirect            S3 event notification
                                                        |
                                                        v
                                                 Lambda (processor)
                                                        |
                                            .-----------+-----------.
                                            |                       |
                                            v                       v
                                     DynamoDB UpdateItem       SQS DLQ
                                  (atomic click increment)  (on retry exhaustion)
```

### Write path

`POST /create` hits API Gateway, which proxies to a Python Lambda. The Lambda fetches credentials from Secrets Manager (cached across warm invocations), generates an 8-character code via `secrets.token_urlsafe`, and inserts the mapping into RDS Postgres via the RDS Proxy. Returns `{"short_url": "https://ghostlink.lol/{code}"}`.

### Read path

`GET /{code}` resolves through CloudFront (WAF-protected) to the ALB. A FastAPI app on ECS Fargate looks up the code in Postgres via the RDS Proxy, writes a click event JSON to S3, and returns a 302 redirect.

### Stats endpoint

`GET /{code}/stats` returns the original URL, creation timestamp, and live click count by joining Postgres and DynamoDB in the create Lambda.

### Click processor

S3 event notifications on `clicks/` trigger a processor Lambda. It parses the click JSON and performs an atomic `ADD` on the `click_count` attribute in DynamoDB. On retry exhaustion, the failed event is forwarded to an SQS dead-letter queue for recovery.

### Frontend

A single-file static SPA served from S3 via CloudFront. Shows click counts per generated link with inline refresh. Session log persists across page refreshes via `localStorage`.

---

## Infrastructure

All infrastructure is Terraform. No hardcoded ARNs or account IDs.

```
infra/
  modules/
    vpc/              VPC, subnets, IGW, NAT gateway, route tables
    s3/               Click-events bucket
    dynamodb/         click_counts table
    rds/              Postgres 15, db.t3.micro, RDS Proxy, Secrets Manager
    iam/              Roles for Fargate, Lambda-create, Lambda-processor
    lambda-create/    Lambda + API Gateway HTTP API (create + stats routes)
    lambda-processor/ S3-triggered Lambda + SQS DLQ
    fargate/          ECR, ECS cluster, task definition, ALB
    frontend/         S3 site bucket, CloudFront, ACM cert, Route 53
    dns/              Persistent Route 53 zone (prevent_destroy)
    monitoring/       WAF WebACL, CloudWatch dashboard
    cicd/             GitHub OIDC provider, CI/CD IAM role
  envs/
    us-east-1/        Root module — wires all modules together
```

### Remote state

| Resource | Name |
|---|---|
| S3 bucket | `phantom-link-tfstate` |
| DynamoDB lock table | `phantom-link-tfstate-lock` |

### Key design decisions

| Decision | Reason |
|---|---|
| Fargate for redirect, Lambda for create | Redirect needs persistent connections and low p99. Lambda suits the stateless write path. |
| RDS Proxy | Lambda cold starts open new Postgres connections. The proxy pools ~80 connections and multiplexes thousands of Lambda invocations across them. |
| Secrets Manager | Credentials never appear in Terraform state or task definitions. Cached at the module level to avoid per-invocation API calls. |
| DynamoDB ADD for click counts | Atomic server-side increment — no read-modify-write race under concurrent load. |
| S3 event pipeline for clicks | Decouples the redirect path from the counter. A slow DynamoDB write never blocks a redirect. |
| SQS DLQ on processor | Failed click events are captured for recovery rather than silently dropped after retries. |
| CloudFront path-based routing | Single domain for SPA and short-link redirects. `/` to S3, `/*` to ALB. |
| WAF rate limiting | Blocks IPs exceeding 2000 req/5 min at the CloudFront edge. AWS managed rules (OWASP Top 10) run in count mode. |
| DNS `prevent_destroy` | Route 53 nameservers are permanent for the lifetime of a zone. Protecting the zone means the registrar only needs to be updated once. |
| GitHub Actions + OIDC | No long-lived AWS credentials in CI. Short-lived tokens scoped to this repo via trust policy. |
| Structured JSON logging | Every log line is a queryable JSON record in CloudWatch Logs Insights. |

---

## CI/CD

Two GitHub Actions workflows:

- **`ci.yml`** — runs on every PR: `terraform fmt`, validate, plan. Plan output posted as a PR comment.
- **`cd.yml`** — runs on every push to `main`: `terraform apply` → push ECR image → force ECS deploy → deploy Lambda → deploy frontend.

Authentication uses OIDC — no AWS access keys stored in GitHub secrets.

---

## Deployment

### First-time setup

```bash
# bootstrap remote state backend
bash scripts/initialize_aws.sh

# apply all infrastructure
terraform -chdir=infra/envs/us-east-1 init
terraform -chdir=infra/envs/us-east-1 apply

# get the CI/CD role ARN and add it to GitHub secrets as AWS_ROLE_ARN
terraform -chdir=infra/envs/us-east-1 output cicd_role_arn
```

Point your domain registrar at the `route53_nameservers` output. After DNS propagation, push to `main` — the pipeline handles everything else.

### Manual deploy (without CI)

```bash
bash scripts/push_image.sh
bash scripts/deploy_lambda_create.sh --full
bash scripts/deploy_frontend.sh
```

### Teardown

```bash
bash scripts/teardown.sh          # preserve Route 53 zone
bash scripts/teardown.sh --full   # full wipe including DNS
```

---

## Usage

### Shorten a URL

```bash
curl -X POST https://ghostlink.lol/create \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

```json
{"short_url": "https://ghostlink.lol/AetqWRgn"}
```

### Get stats

```bash
curl https://ghostlink.lol/AetqWRgn/stats
```

```json
{"short_code": "AetqWRgn", "long_url": "https://example.com", "click_count": 4, "created_at": "2025-04-21T14:00:00+00:00"}
```

---

## Repository structure

```
phantom-link/
├── frontend/
│   └── index.html              Static SPA
├── infra/
│   ├── modules/                Terraform modules
│   └── envs/us-east-1/         Environment root module
├── lambdas/
│   ├── create/                 POST /create + GET /{code}/stats
│   └── processor/              S3 click event processor
├── services/
│   └── redirect/               FastAPI redirect service (Fargate)
├── scripts/
│   ├── initialize_aws.sh       One-time state backend bootstrap
│   ├── deploy_lambda_create.sh Lambda build and deploy
│   ├── deploy_frontend.sh      S3 sync and CloudFront invalidation
│   ├── push_image.sh           ECR image build and push
│   └── teardown.sh             Ordered infrastructure teardown
└── docs/
    └── phase_*.md              Per-phase build notes and decisions
```

---

## Stack

| Layer | Technology |
|---|---|
| Infrastructure | Terraform >= 1.7, AWS provider ~> 5.0 |
| CI/CD | GitHub Actions + AWS OIDC |
| Runtime | Python 3.12 |
| Database | RDS Postgres 15, db.t3.micro + RDS Proxy |
| Compute | AWS Lambda, ECS Fargate |
| API | API Gateway HTTP API (v2) |
| CDN / Security | CloudFront, WAF (rate limit + managed rules) |
| DNS | Route 53 |
| Storage | S3, DynamoDB (PAY_PER_REQUEST) |
| Secrets | AWS Secrets Manager |
| Messaging | SQS (DLQ) |
| Observability | CloudWatch Logs (structured JSON), CloudWatch Dashboard |
| Container registry | Amazon ECR |
| Networking | VPC, ALB, NAT Gateway |
