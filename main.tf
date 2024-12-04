terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tfstate-demo-app-remote-backend-2024-12-04-03-10-20"
    key            = "devops-directive-terraform/demo-app-1/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "tfstate-demo-app-remote-lock"
    encrypt        = true
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# vpc
resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.common_tags.Name} VPC"
  }
}

# sub-network 
resource "aws_subnet" "demo_subnet" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone[0]

  tags = {
    Name = "${local.common_tags.Name} Subnet"
  }
}

# internet gateway - for public access
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "${local.common_tags.Name} IGW"
  }
}

# route table - for public access
resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "${local.common_tags.Name} RT"
  }
}


# security group
resource "aws_security_group" "demo_sg" {
  vpc_id = aws_vpc.demo_vpc.id

  ingress = [
    # for ssh connection
    {
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow all ssh connection"
      ipv6_cidr_blocks = []
      self             = false
      security_groups  = null
      prefix_list_ids  = null
    },
    # for http connection
    {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow all http inbound traffic"
      ipv6_cidr_blocks = []
      self             = false
      security_groups  = null
      prefix_list_ids  = null
    }
  ]


  egress = [
    # all outbound request are allowed
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Allow all outbound traffic"
      ipv6_cidr_blocks = []   # If you need to allow IPv6, specify the block here
      self             = true # Refers to allowing traffic to and from the security group itself
      security_groups  = null
      prefix_list_ids  = null
    }
  ]

  tags = {
    Name = "${local.common_tags.Name} SG"
  }
}

# aws_key pair
resource "aws_key_pair" "demo_key" {
  key_name   = "devops-directive-demo-key"
  public_key = file(var.ssh_key_path)
}

# data for aws_ami
data "aws_ami" "ubuntu" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ec2 instance-1
resource "aws_instance" "ec2_a" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.demo_subnet.id
  vpc_security_group_ids      = [aws_security_group.demo_sg.id]
  key_name                    = aws_key_pair.demo_key.key_name
  associate_public_ip_address = true
  user_data                   = file("entry_script.sh")

  tags = {
    Name = "${local.common_tags.Name} EC2 instance 1"
  }
}

# ec2 instance-1
resource "aws_instance" "ec2_b" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.demo_subnet.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  key_name = aws_key_pair.demo_key.key_name
  associate_public_ip_address = true
  user_data = file("entry_script.sh")

  tags = {
    Name = "${local.common_tags.Name} EC2 instance 2"
  }
}

# s3 bucket for the application
resource "aws_s3_bucket" "bucket" {
    bucket = "devops-directive-demo-app-data-2024-12-04-03-10-20"
    force_destroy = true
}

# encryption of the data in the s3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "data_encryption" {
  bucket = aws_s3_bucket.bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Use the default AES256 encryption algorithm
    }
  }
}
