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
