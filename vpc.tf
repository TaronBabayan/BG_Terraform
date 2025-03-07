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
