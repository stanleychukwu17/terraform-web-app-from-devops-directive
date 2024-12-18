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

# sub-network-1
resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_availability_zone[0]

  tags = {
    Name = "${local.common_tags.Name} Subnet 1"
  }
}

# sub-network-2
resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.aws_availability_zone[1]

  tags = {
    Name = "${local.common_tags.Name} Subnet 2"
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

# association of the route table to the subnet
resource "aws_route_table_association" "rt_association_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.demo_rt.id
}

resource "aws_route_table_association" "rt_association_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.demo_rt.id
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
      self             = false # Refers to allowing traffic to and from the security group itself
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
  #ami                         = "ami-05edb7c94b324f73c"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_1.id
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
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_2.id
  vpc_security_group_ids      = [aws_security_group.demo_sg.id]
  key_name                    = aws_key_pair.demo_key.key_name
  associate_public_ip_address = true
  user_data                   = file("entry_script.sh")

  tags = {
    Name = "${local.common_tags.Name} EC2 instance 2"
  }
}

# s3 bucket for the application
resource "aws_s3_bucket" "bucket" {
  bucket        = "devops-directive-demo-app-data-2024-12-04-03-10-20"
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "ec2_instances" {
  name     = "devops-directive-demo-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "ec2_a" {
  target_group_arn = aws_lb_target_group.ec2_instances.arn
  target_id        = aws_instance.ec2_a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "ec2_b" {
  target_group_arn = aws_lb_target_group.ec2_instances.arn
  target_id        = aws_instance.ec2_b.id
  port             = 8080
}

resource "aws_lb_listener_rule" "ec2_instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_instances.arn
  }

  condition {
    path_pattern {
      values = ["*"] # or ["/*"]
    }
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.demo_vpc.id

  ingress = [
    # Allow HTTP traffic from the ALB on port 80
    {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = var.allowed_http_ip
      description      = "Allow all http inbound traffic"
      ipv6_cidr_blocks = []
      self             = false
      security_groups  = null
      prefix_list_ids  = null
    },

    # Allow HTTP traffic on port 8080 from the ALB to EC2 instances
    # EC2 instances are registered with the target group on port 8080
    {
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = var.allowed_http_ip
      description      = "Allow all http inbound traffic on port 8080"
      ipv6_cidr_blocks = []
      self             = false
      security_groups  = null
      prefix_list_ids  = null
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = var.allowed_outbound_ip
      description      = "Allow all outbound traffic"
      ipv6_cidr_blocks = []
      self             = false
      security_groups  = null
      prefix_list_ids  = null
    }
  ]
}

resource "aws_lb" "load_balancer" {
  name               = "devops-directive-demo-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_route53_zone" "primary" {
  name = "stanleychukwu.com"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = aws_route53_zone.primary.name
  type    = "A"

  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_db_instance" "db_postgres_instance" {
  count               = 0
  allocated_storage   = 20
  storage_type        = "standard"
  engine              = "postgres"
  engine_version      = "15.7"
  instance_class      = "db.t3.micro"
  db_name             = "devops_directive_demo_db"
  username            = "stanley"
  password            = "stanley123"
  skip_final_snapshot = true
}