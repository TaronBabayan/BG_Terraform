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
