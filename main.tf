terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {

  access_key = var.access_key
  secret_key = var.secret_key
  region = "us-east-1"
}


#VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Project = "KPMG tech challenge"
  }
}


#public subnet
resource "aws_subnet" "pub_sub" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.168.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Project = "public subnet"
  }
}


#Private subnet 1 web server application
resource "aws_subnet" "prv_sub 1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.168.20.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Project = "web server subnet"
  }
}

#Private subnet 2 for Database
resource "aws_subnet" "prv_sub 2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "192.168.30.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Project = "database subnet"
  }
}


#Internet Gateway to route traffic between our subnets and the internet
resource "aws_internet_gateway" "igateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Project = "KPMG tech challenge"
  }
}

#Public Subnet Route Table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Project = "KPMG tech challenge"
  }
}

#Associate with Public Subnet Route Table
resource "aws_route_table_association" "route_assoc" {
  subnet_id      = aws_subnet.pub_sub.id
  route_table_id = aws_route_table.pub_rt.id
}


#NAT Gateway and Elastic IP
resource "aws_eip" "nat_eip" {
  vpc = true

  tags = {
    Project = "KPMG tech challenge"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_sub.id

  tags = {
    Project = "KPMG tech challenge"
  }
}

#Private Subnet1 Route Table
resource "aws_route_table" "prv_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Project = "sdn-tutorial"
  }
}

#Associate with private Subnet1 Route Table
resource "aws_route_table_association" "prv_rt_assoc" {
  subnet_id      = aws_subnet.prv_sub.id
  route_table_id = aws_route_table.prv_rt.id
}

# ./security.tf

resource "aws_security_group" "general_sg" {
  description = "HTTP egress to anywhere"
  vpc_id      = aws_hvpc.main.id

  tags = {
    Project = "KPMG tech challenge"
  }
}

resource "aws_security_group" "bastion_sg" {
  description = "SSH ingress to Bastion and SSH egress to App"
  vpc_id      = aws_vpc.main.id

  tags = {
    Project = "KPMG tech challenge"
  }
}

resource "aws_security_group" "app_sg" {
  description = "SSH ingress from Bastion and all TCP traffic ingress from ALB Security Group"
  vpc_id      = aws_vpc.main.id
  tags = {
    Project = "KPMG tech challenge"
  }
}

resource "aws_security_group" "database_sg" {
  description = "SSH ingress from Bastion and all TCP traffic ingress from ALB Security Group"
  vpc_id      = aws_vpc.main.id
  tags = {
    Project = "KPMG tech challenge"
  }
}

#Egress rules

resource "aws_security_group_rule" "out_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.general_sg.id
}

resource "aws_security_group_rule" "out_ssh_bastion" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

resource "aws_security_group_rule" "out_http_app" {
  type              = "egress"
  description       = "Allow TCP internet traffic egress from app layer"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_sg.id
}

#ingress rules
resource "aws_security_group_rule" "in_ssh_bastion_from_anywhere" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "in_ssh_app_from_bastion" {
  type                     = "ingress"
  description              = "Allow SSH from a Bastion Security Group"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

#app egress

resource "aws_security_group_rule" "out_ssh_bastion" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.db_sg.id
}

#db ingress
resource "aws_security_group_rule" "in_ssh_app_from_bastion" {
  type                     = "ingress"
  description              = "Allow SSH from a app Security Group"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

#db egress
resource "aws_security_group_rule" "out_http_app" {
  type              = "egress"
  description       = "Allow TCP internet traffic egress from DB layer"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db_sg.id
}
