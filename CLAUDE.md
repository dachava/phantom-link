# CLAUDE.md — phantom-link

## Project

Production-style URL shortener live at ghostlink.lol. Built phase by phase
for interview prep. All infrastructure is Terraform, all deploys go through
GitHub Actions CI/CD on push to `main`.

## Stack at a glance

| Layer | What |
|---|---|
| Compute | Lambda (create + stats), ECS Fargate (redirect) |
| Database | RDS Postgres 15 via RDS Proxy |
| API | API Gateway HTTP API v2 |
| CDN | CloudFront + WAF |
| Click pipeline | S3 → Lambda processor → DynamoDB → SQS DLQ |
| Frontend | Single HTML file in S3 |
| IaC | Terraform, modular, remote state in S3 + DynamoDB |
| CI/CD | GitHub Actions + AWS OIDC (no long-lived credentials) |
| Observability | Structured JSON logs, CloudWatch dashboard |

## Repo structure

```
frontend/               Static SPA (index.html)
infra/
  modules/
    vpc/                VPC, subnets, IGW, NAT, route tables
    s3/                 Click-events bucket
    dynamodb/           click_counts table
    rds/                Postgres 15 + RDS Proxy + Secrets Manager
    iam/                Roles for Fargate, Lambda-create, Lambda-processor
    lambda-create/      Lambda + API Gateway (POST /create, GET /{code}/stats)
    lambda-processor/   S3-triggered Lambda + SQS DLQ
    fargate/            ECR, ECS cluster + service, ALB
    frontend/           S3 site bucket, CloudFront, ACM, Route 53 record
    dns/                Route 53 zone with prevent_destroy
    monitoring/         WAF WebACL + CloudWatch dashboard
    cicd/               GitHub OIDC provider + CI/CD IAM role
  envs/us-east-1/       Root module — wires everything together
lambdas/
  create/               handler.py — create + stats routes
  processor/            handler.py — click event processor
services/
  redirect/             FastAPI app (Fargate), app.py + Dockerfile
scripts/
  initialize_aws.sh     One-time state backend bootstrap
  deploy_lambda_create.sh  Build and push Lambda (--full rebuilds deps)
  deploy_frontend.sh    Inject API URL, sync to S3, invalidate CloudFront
  push_image.sh         Build and push ECR image
  teardown.sh           Ordered destroy (--full includes DNS zone)
docs/
  phase_*.md            Per-phase build notes, decisions, troubleshooting
  project_summary.md    Full architecture summary for blog / interviews
```

## Code conventions

- **Comment format:** `### [comment] ###` in all Terraform and Bash files — no other style
- **No inline comments explaining what code does** — only comments for non-obvious WHY
- **Terraform naming:** `${var.project}-${var.env}-<resource>` e.g. `phantom-link-dev-proxy`
- **Python logging:** structured JSON via `log(level, **kwargs)` — never bare `print()`
- **No boto3 in requirements.txt** — it is pre-installed in the Lambda runtime

## Key behaviors to know

**Lambda deps in CI:** `deploy_lambda_create.sh --full` uses Docker locally (macOS needs cross-compilation). In CI (`cd.yml`) deps are built with `pip install --target` directly on the runner — the runner is already Linux x86_64, same as Lambda. Never add `--platform` flags; they silently skip pure-Python packages.

**`package/` is not in git.** The `lambdas/create/package/` directory is a build artifact. CI builds it fresh every run. Locally it persists between deploys.

**API endpoint injection:** `frontend/index.html` contains `__API_ENDPOINT__` and `__API_BASE_URL__` placeholders. `deploy_frontend.sh` replaces them with live Terraform outputs before syncing to S3.

**Route 53 zone:** Has `prevent_destroy = true`. `terraform destroy` alone will error. Use `scripts/teardown.sh` which handles the ordered sequence. Pass `--full` to also destroy the DNS zone.

**RDS Proxy:** Takes 3–5 minutes to become `available` after `terraform apply`. The CD pipeline polls for this before proceeding to ECS/Lambda deploys.

**CloudFront + WAF:** WAF scope `CLOUDFRONT` must be provisioned in `us-east-1`. Managed rules (`AWSManagedRulesCommonRuleSet`) are in `count` mode for dev — they log but do not block.

**OIDC:** GitHub Actions assumes `phantom-link-dev-cicd` IAM role. The role ARN is stored as `AWS_ROLE_ARN` in GitHub repo secrets. Run `terraform output cicd_role_arn` to get it.

## Lambda handler routing

The create Lambda handles multiple routes. Route dispatch uses `event["routeKey"]`:

```python
if method == "OPTIONS":    → CORS preflight
if route_key == "POST /create"         → handle_create()
if route_key == "GET /{code}/stats"    → handle_stats()
```

Path parameters come from `event["pathParameters"]["code"]`.

## DynamoDB schema

Table: `phantom-link-dev-click-counts`
- Hash key: `short_code` (String)
- Attribute: `click_count` (Number) — incremented by processor via `ADD`

## Terraform outputs (useful ones)

```bash
terraform -chdir=infra/envs/us-east-1 output api_endpoint          # POST /create URL
terraform -chdir=infra/envs/us-east-1 output api_base_url          # base for /{code}/stats
terraform -chdir=infra/envs/us-east-1 output cloudfront_distribution_id
terraform -chdir=infra/envs/us-east-1 output s3_site_bucket_name
terraform -chdir=infra/envs/us-east-1 output cicd_role_arn
terraform -chdir=infra/envs/us-east-1 output dlq_url
terraform -chdir=infra/envs/us-east-1 output dashboard_name
```

## Startup sequence after terraform apply

1. Wait for RDS Proxy: `aws rds describe-db-proxies --db-proxy-name phantom-link-dev-proxy --region us-east-1 --query 'DBProxies[0].Status' --output text`
2. `bash scripts/push_image.sh`
3. Force ECS: `aws ecs update-service --cluster phantom-link-redirect-dev --service phantom-link-redirect-dev --force-new-deployment --region us-east-1 | cat`
4. `bash scripts/deploy_lambda_create.sh --full`
5. `bash scripts/deploy_frontend.sh`

With CI/CD active, pushing to `main` runs all of these automatically.

## Phases completed

| Phase | What |
|---|---|
| 1 | Remote state, VPC |
| 2 | RDS, Secrets Manager |
| 3 | Lambda create, API Gateway |
| 4 | Fargate redirect service |
| 5 | Click tracking pipeline (S3 → Lambda → DynamoDB) |
| 6 | CloudFront, ACM, Route 53, frontend |
| 7 | RDS Proxy, DNS persistence, teardown script, operational fixes |
| 8 | CI/CD — GitHub Actions + OIDC |
| 9 | Stats endpoint GET /{code}/stats, localStorage session |
| 10 | WAF rate limiting, CloudWatch dashboard |
| 11 | Structured JSON logging across Lambda and Fargate |
| 12 | SQS DLQ for click processor |

## Known limitations

- Click write to S3 is synchronous on the redirect path — adds ~10–50ms latency
- Single NAT gateway — not HA across AZs
- Managed WAF rules in count mode only
- No URL validation on create
- No auth — API is open, WAF rate limit is the only protection
- `require_tls = false` on RDS Proxy (VPC-private, acceptable for dev)

## Potential next phases

- CloudWatch Alarms (error rate, DLQ depth > 0)
- URL expiry (TTL column + 410 Gone)
- X-Ray tracing
- Per-user auth and link management
- SQS native DLQ redriving
