output "table_name" {
  value = aws_dynamodb_table.click_counts.name
}

output "table_arn" {
  value = aws_dynamodb_table.click_counts.arn
}
