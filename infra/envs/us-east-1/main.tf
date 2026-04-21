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
  secret_arn         = module.rds.secret_arn
}
