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
