resource "aws_ecs_cluster" "ecs_cluster" {
  name = "bgene_cluster"
}


resource "aws_ecs_capacity_provider" "ecs_cp" {
  name = "bgene-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cp_attach" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_cp.name]
}

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name  = "web-container"
      image = "kennethreitz/httpbin"
      portMappings = [{
        containerPort = 80
        hostPort      = 80
      }]
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name            = "web-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 3

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 100
  }

  network_configuration {
    subnets          = slice(aws_subnet.private[*].id, 0, 3) # Use first 3 private subnets for ECS
    security_groups  = [aws_security_group.servers_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs_tg.arn
    container_name   = "web-container"
    container_port   = 80
  }

  depends_on = [aws_alb_listener.http, aws_autoscaling_group.ecs_asg, aws_nat_gateway.nat]
}





