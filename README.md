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
  |                         RDS Postgres (private subnet)
  |
  |-- GET /{code} ---------> CloudFront
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
                        RDS Postgres             S3 click event
                        (lookup)               clicks/{code}/{ts}.json
                              |                         |
                              v                         v
                         302 redirect            S3 event notification
                                                        |
                                                        v
                                                 Lambda (processor)
                                                        |
                                                        v
                                                 DynamoDB UpdateItem
                                              (atomic click increment)
```

### Write path

`POST /create` hits API Gateway, which proxies to a Python Lambda. The Lambda fetches database credentials from Secrets Manager (cached across warm invocations), generates an 8-character URL-safe code via `secrets.token_urlsafe`, and inserts the mapping into RDS Postgres. Returns `{"short_url": "https://ghostlink.lol/{code}"}`.

### Read path

`GET /{code}` resolves through CloudFront to the Application Load Balancer. A FastAPI app running on ECS Fargate looks up the short code in RDS, writes a click event JSON object to S3, and returns a 302 redirect to the original URL.

### Click processor

S3 event notifications on the `clicks/` prefix trigger a Lambda. It reads the click JSON, parses the short code, and performs an atomic `ADD` increment on the `click_count` attribute in DynamoDB. At-least-once delivery; concurrent increments are safe.

### Frontend

A single-file static SPA served from S3 via CloudFront. Calls the API Gateway endpoint directly from the browser.

---

## Infrastructure

All infrastructure is defined in Terraform. No hardcoded ARNs or account IDs.

```
infra/
  modules/
    vpc/              VPC, subnets, IGW, NAT gateway, route tables
    s3/               Click-events bucket
    dynamodb/         click_counts table
    rds/              Postgres 15, db.t3.micro, Secrets Manager credentials
    iam/              Roles for Fargate, Lambda-create, Lambda-processor
    lambda-create/    Lambda function + API Gateway HTTP API
    lambda-processor/ S3-triggered Lambda + DynamoDB permission
    fargate/          ECR, ECS cluster, task definition, service, ALB
    frontend/         S3 site bucket, CloudFront, ACM cert, Route 53
  envs/
    us-east-1/        Root module — wires all modules together
```

### Remote state

| Resource | Name |
|---|---|
| S3 bucket | `phantom-link-tfstate` |
| DynamoDB lock table | `phantom-link-tfstate-lock` |
| Region | `us-east-1` |

### Key design decisions

| Decision | Reason |
|---|---|
| Fargate for redirect, Lambda for create | Redirect needs persistent DB connections and low p99 latency. Lambda suits the stateless, infrequent write path. |
| Secrets Manager over env vars | Credentials never appear in Terraform state or ECS task definitions. Supports rotation. |
| DynamoDB ADD for click counts | Atomic server-side increment. No read-modify-write race condition under concurrent load. |
| S3 event notifications for click pipeline | Decouples the redirect service from the counter. Redirect path has no dependency on DynamoDB. |
| CloudFront path-based routing | Single domain serves both the SPA and short-link redirects. `/` to S3, `/*` to ALB. |
| Single NAT gateway | Cost trade-off for a dev deployment. One NAT serves all private subnets. |
| PAY_PER_REQUEST on DynamoDB | Click traffic is bursty. No capacity planning, scales instantly. |

---

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.7
- Docker (for building Lambda dependency packages)
- A domain with nameservers pointing to the Route 53 hosted zone

---

## Deployment

### 1. Bootstrap remote state

Run once per AWS account before the first `terraform apply`.

```bash
bash scripts/initialize_aws.sh
```

This creates the S3 state bucket and DynamoDB lock table.

### 2. Apply infrastructure

```bash
cd infra/envs/us-east-1
terraform init
terraform apply
```

On first apply, note the `route53_nameservers` output and point your domain registrar at those nameservers. Wait for DNS propagation before proceeding.

### 3. Build and push the redirect service image

```bash
bash scripts/push_image.sh
```

Then force a new ECS deployment:

```bash
aws ecs update-service \
  --cluster phantom-link-redirect-dev \
  --service phantom-link-redirect-dev \
  --force-new-deployment \
  --region us-east-1 | cat
```

### 4. Deploy the Lambda create handler

First deploy (builds psycopg2 via Docker for Amazon Linux compatibility):

```bash
bash scripts/deploy_lambda_create.sh --full
```

Subsequent deploys (handler changes only):

```bash
bash scripts/deploy_lambda_create.sh
```

### 5. Deploy the frontend

```bash
bash scripts/deploy_frontend.sh
```

Syncs `frontend/` to S3 and invalidates the CloudFront cache.

---

## Usage

### Shorten a URL via the UI

Visit [ghostlink.lol](https://ghostlink.lol), paste a URL, and click **shorten_**.

### Shorten a URL via the API

```bash
curl -X POST https://ghostlink.lol/create \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

Response:

```json
{"short_url": "https://ghostlink.lol/AetqWRgn"}
```

### Check click count

```bash
aws dynamodb get-item \
  --table-name phantom-link-dev-click-counts \
  --key '{"short_code": {"S": "AetqWRgn"}}' \
  --region us-east-1
```

---

## Repository structure

```
phantom-link/
├── frontend/
│   └── index.html              Static SPA
├── infra/
│   ├── modules/                Reusable Terraform modules
│   └── envs/us-east-1/         Environment root module
├── lambdas/
│   ├── create/                 POST /create handler
│   └── processor/              S3 click event processor
├── services/
│   └── redirect/               FastAPI redirect service (Fargate)
│       ├── app.py
│       ├── Dockerfile
│       └── requirements.txt
└── scripts/
    ├── initialize_aws.sh       One-time state backend bootstrap
    ├── deploy_lambda_create.sh Lambda build and deploy
    ├── deploy_frontend.sh      S3 sync and CloudFront invalidation
    └── push_image.sh           ECR image build and push
```

---

## Stack

| Layer | Technology |
|---|---|
| Infrastructure | Terraform >= 1.7, AWS provider ~> 5.0 |
| Runtime | Python 3.12 |
| Database | RDS Postgres 15, db.t3.micro |
| Compute | AWS Lambda, ECS Fargate |
| API | API Gateway HTTP API (v2) |
| CDN | CloudFront (PriceClass_100) |
| DNS | Route 53 |
| Storage | S3, DynamoDB |
| Secrets | AWS Secrets Manager |
| Container registry | Amazon ECR |
| Networking | VPC, ALB, NAT Gateway |
