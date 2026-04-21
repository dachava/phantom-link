locals {
  table_name = "${var.project}-${var.env}-click-counts"
}

resource "aws_dynamodb_table" "click_counts" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }

  tags = { Name = local.table_name }
}
