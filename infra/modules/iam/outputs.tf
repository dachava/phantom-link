output "fargate_execution_role_arn" {
  value = aws_iam_role.fargate_execution.arn
}

output "fargate_task_role_arn" {
  value = aws_iam_role.fargate_task.arn
}

output "lambda_create_role_arn" {
  value = aws_iam_role.lambda_create.arn
}

output "lambda_processor_role_arn" {
  value = aws_iam_role.lambda_processor.arn
}
