locals {
  table_name = "${var.project}-${var.env}-${var.table_suffix}"
}

resource "aws_dynamodb_table" "click_counts" {
  name         = local.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  tags = merge({ Name = local.table_name }, var.tags)
}
