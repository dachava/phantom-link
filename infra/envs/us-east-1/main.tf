module "vpc" {
  source = "../../modules/vpc"

  project  = var.project
  env      = var.env
  vpc_cidr = var.vpc_cidr
  az_count = var.az_count
}
