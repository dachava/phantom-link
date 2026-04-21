locals {
  name_prefix = "${var.project}-${var.environment}"
}

### [waf — cloudfront scope must be us-east-1] ###
resource "aws_wafv2_web_acl" "cloudfront" {
  name  = "${local.name_prefix}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  ### [rate limit — block ips exceeding threshold per 5 min] ###
  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  ### [aws managed common rules — owasp top 10, count mode for dev] ###
  rule {
    name     = "aws-managed-common"
    priority = 2

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-managed-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${local.name_prefix}-waf" }
}

### [cloudwatch dashboard] ###
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      ### [row 1 — lambda] ###
      {
        type   = "metric"
        x = 0; y = 0; width = 8; height = 6
        properties = {
          title   = "Lambda — Invocations"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name]]
        }
      },
      {
        type   = "metric"
        x = 8; y = 0; width = 8; height = 6
        properties = {
          title   = "Lambda — Errors"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name]]
          annotations = {
            horizontal = [{ value = 1, color = "#ff6961", label = "any error" }]
          }
        }
      },
      {
        type   = "metric"
        x = 16; y = 0; width = 8; height = 6
        properties = {
          title   = "Lambda — Duration p95 (ms)"
          region  = "us-east-1"
          stat    = "p95"
          period  = 300
          metrics = [["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name]]
        }
      },

      ### [row 2 — ecs] ###
      {
        type   = "metric"
        x = 0; y = 6; width = 12; height = 6
        properties = {
          title   = "ECS — CPU Utilization %"
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [[
            "AWS/ECS", "CPUUtilization",
            "ClusterName", var.ecs_cluster_name,
            "ServiceName", var.ecs_service_name
          ]]
        }
      },
      {
        type   = "metric"
        x = 12; y = 6; width = 12; height = 6
        properties = {
          title   = "ECS — Memory Utilization %"
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [[
            "AWS/ECS", "MemoryUtilization",
            "ClusterName", var.ecs_cluster_name,
            "ServiceName", var.ecs_service_name
          ]]
        }
      },

      ### [row 3 — rds + dynamodb + waf] ###
      {
        type   = "metric"
        x = 0; y = 12; width = 8; height = 6
        properties = {
          title   = "RDS — DB Connections"
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id]]
        }
      },
      {
        type   = "metric"
        x = 8; y = 12; width = 8; height = 6
        properties = {
          title   = "DynamoDB — Consumed Read Units"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name]]
        }
      },
      {
        type   = "metric"
        x = 16; y = 12; width = 8; height = 6
        properties = {
          title   = "WAF — Blocked Requests"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [[
            "AWS/WAFV2", "BlockedRequests",
            "WebACL", "${local.name_prefix}-waf",
            "Region", "us-east-1",
            "Rule", "rate-limit"
          ]]
        }
      }
    ]
  })
}
