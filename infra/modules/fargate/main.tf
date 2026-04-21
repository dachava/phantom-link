locals {
  name = "phantom-link-redirect-${var.env}"
}

### [ecr] ###
resource "aws_ecr_repository" "redirect" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = local.name }
}

### [security groups] ###
# The ALB accepts traffic from the internet on port 80
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Allow inbound HTTP from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# The ECS tasks only accept traffic from the ALB security group on port 8080
resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "Allow inbound from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-ecs-sg" }
}

### [alb] ###
resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = { Name = "${local.name}-alb" }
}

resource "aws_lb_target_group" "this" {
  name        = "${local.name}-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip" # target group registers the task's private IP directly, only for "awsvpc" network mode
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${local.name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

### [ecs] ###
resource "aws_ecs_cluster" "this" {
  name = local.name
  tags = { Name = local.name }
}

resource "aws_ecs_task_definition" "redirect" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  task_role_arn            = var.fargate_task_role_arn
  execution_role_arn       = var.fargate_execution_role_arn

  container_definitions = jsonencode([{
    name      = "redirect"
    image     = "${aws_ecr_repository.redirect.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "DB_HOST",             value = var.db_host },
      { name = "DB_NAME",             value = var.db_name },
      { name = "DB_SECRET_ARN",       value = var.db_secret_arn },
      { name = "CLICK_EVENTS_BUCKET", value = var.click_events_bucket },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${local.name}"
        awslogs-region        = var.region
        awslogs-stream-prefix = "redirect"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
  tags              = { Name = local.name }
}

resource "aws_ecs_service" "redirect" {
  name            = local.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.redirect.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "redirect"
    container_port   = 8080
  }

# The ECS service needs the listener to exist before it registers tasks with the target group
# otherwise the service creates but health checks never start
  depends_on = [aws_lb_listener.http]

  tags = { Name = local.name }
}