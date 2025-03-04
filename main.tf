resource "aws_vpc" "bgene_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "bgene-proj"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.bgene_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bgene_vpc.cidr_block, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = 5
  vpc_id            = aws_vpc.bgene_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.bgene_vpc.cidr_block, 8, count.index + 2)
  availability_zone = element(data.aws_availability_zones.available.names, count.index % 2)
  tags = {
    Name = "private-subnet-${count.index}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.bgene_vpc.id
  tags = {
    Name = "bgene_vpc-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id     = aws_eip.nat.id
  connectivity_type = "public"
  subnet_id         = aws_subnet.public[0].id
  tags = {
    Name = "bgene_vpc-nat"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.bgene_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.bgene_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  count          = 5
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.bgene_vpc.id
  name   = "alb_sg"

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
}

resource "aws_security_group" "servers_sg" {
  vpc_id = aws_vpc.bgene_vpc.id
  name   = "servers_sg"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.bgene_vpc.id
  name   = "bastion"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.bgene_vpc.id
  name   = "rds_sg"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.servers_sg.id] # Only allow access from web servers
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  subnet_id       = aws_subnet.public[0].id
  ami             = "ami-04b4f1a9cf54c11d0"
  instance_type   = "t3.micro"
  key_name        = "bostongene"
  security_groups = [aws_security_group.bastion_sg.id]
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "bastion"
  }
}


resource "aws_ecs_cluster" "ecs_cluster" {
  name = "bgene_cluster"
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
  desired_count   = 2

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

  depends_on = [aws_alb_listener.http, aws_autoscaling_group.ecs_asg, aws_nat_gateway.nat] # Add depends_on
}

resource "aws_alb" "ecs_alb" {
  name               = "ecs-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public[0].id, aws_subnet.public[1].id] # Use different AZs
}

resource "aws_alb_target_group" "ecs_tg" {
  name        = "ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.bgene_vpc.id

}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_tg.arn
  }
}

resource "aws_launch_template" "ecs_lt" {
  name          = "ecs-launch-template"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.micro"
  key_name      = "bostongene"
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name #maybe will be needed to adjust by reference 
  }
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.servers_sg.id]

  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-instance"
    }
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config

EOF
  )
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  min_size            = 1
  max_size            = 4
  desired_capacity    = 3
  vpc_zone_identifier = slice(aws_subnet.private[*].id, 0, 3)
  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }

  depends_on = [aws_ecs_cluster.ecs_cluster, aws_launch_template.ecs_lt, aws_nat_gateway.nat] # to follow correct order
}


data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}




resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}


# RDS PostgreSQL Instance
resource "aws_db_instance" "postgresql" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "17.3"
  instance_class         = "db.t3.micro"
  db_name                = "bgene_db"
  username               = "dbadminn"
  password               = data.aws_ssm_parameter.db_password.value # Retrieve password from Parameter Store
  parameter_group_name   = "default.postgres17"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  multi_az               = false
  skip_final_snapshot    = true
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private[3].id, aws_subnet.private[4].id] # Use the 4th private subnet for RDS
  tags = {
    Name = "rds-subnet-group"
  }
}
# Data Source to Fetch DB Password from Parameter Store
data "aws_ssm_parameter" "db_password" {
  name = "/bgene/prod/db_password" # Replace with your parameter name
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
