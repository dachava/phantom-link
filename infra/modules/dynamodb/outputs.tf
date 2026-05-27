output "table_name" {
  description = "DynamoDB click-counts table name."
  value       = aws_dynamodb_table.click_counts.name
}

output "table_arn" {
  description = "DynamoDB click-counts table ARN."
  value       = aws_dynamodb_table.click_counts.arn
}

output "table_id" {
  description = "DynamoDB table ID (same as table name)."
  value       = aws_dynamodb_table.click_counts.id
}

output "hash_key" {
  description = "Partition key attribute name."
  value       = aws_dynamodb_table.click_counts.hash_key
}

output "billing_mode" {
  description = "Capacity billing mode for the table."
  value       = aws_dynamodb_table.click_counts.billing_mode
}
