module "vpc" {
  source = "../../modules/vpc"

  project  = var.project
  env      = var.env
  vpc_cidr = var.vpc_cidr
  az_count = var.az_count
}

module "s3" {
  source = "../../modules/s3"

  project = var.project
  env     = var.env
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  project = var.project
  env     = var.env
}

module "rds" {
  source = "../../modules/rds"

  project            = var.project
  env                = var.env
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_cidr           = var.vpc_cidr
  db_name            = var.db_name
  db_username        = var.db_username
}

module "iam" {
  source = "../../modules/iam"

  project            = var.project
  env                = var.env
  s3_bucket_arn      = module.s3.bucket_arn
  dynamodb_table_arn = module.dynamodb.table_arn
  secret_arn         = module.rds.db_secret_arn
  click_events_bucket_arn = module.s3.bucket_arn
  click_counts_table_arn  = module.dynamodb.table_arn
}

module "lambda_create" {
  source = "../../modules/lambda-create"

  env                = var.env
  region             = var.aws_region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_host            = module.rds.db_host
  db_name            = module.rds.db_name
  db_secret_arn      = module.rds.db_secret_arn
  base_url           = var.base_url
}

module "fargate" {
  source = "../../modules/fargate"

  env                        = var.env
  region                     = var.aws_region
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  public_subnet_ids          = module.vpc.public_subnet_ids
  db_host                    = module.rds.db_host
  db_name                    = module.rds.db_name
  db_secret_arn              = module.rds.db_secret_arn
  click_events_bucket        = module.s3.bucket_name
  fargate_task_role_arn      = module.iam.fargate_task_role_arn
  fargate_execution_role_arn = module.iam.fargate_execution_role_arn
}

module "lambda_processor" {
  source = "../../modules/lambda-processor"

  env                       = var.env
  click_events_bucket_arn   = module.s3.bucket_arn
  click_events_bucket_name  = module.s3.bucket_name
  click_counts_table_name   = module.dynamodb.table_name
  lambda_processor_role_arn = module.iam.lambda_processor_role_arn
}