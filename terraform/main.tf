terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Using specific Ubuntu AMI ID
locals {
  ami_id = "ami-0036347a8a8be83f1"
}

# Security Group for Chess Application
resource "aws_security_group" "chess_sg" {
  name_prefix = "chess-${var.environment}-"
  description = "Security group for Chess application"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend port
  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend WebSocket port
  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "chess-${var.environment}-sg"
    Environment = var.environment
  }
}

# No SSH key pair needed - using EC2 Instance Connect

# IAM Role for EC2 Instance
resource "aws_iam_role" "chess_instance_role" {
  name = "chess-${var.environment}-instance-role"

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

  tags = {
    Name        = "chess-${var.environment}-instance-role"
    Environment = var.environment
  }
}

# Attach SSM policy to the role
resource "aws_iam_role_policy_attachment" "chess_ssm_policy" {
  role       = aws_iam_role.chess_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "chess_instance_profile" {
  name = "chess-${var.environment}-instance-profile"
  role = aws_iam_role.chess_instance_role.name

  tags = {
    Name        = "chess-${var.environment}-instance-profile"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "chess_app" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.chess_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.chess_instance_profile.name

  user_data = templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    git_repo    = var.git_repo
    branch      = var.branch
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  tags = {
    Name        = "chess-${var.environment}-server"
    Environment = var.environment
    Application = "chess"
  }
}

# Elastic IP for consistent IP address
resource "aws_eip" "chess_eip" {
  instance = aws_instance.chess_app.id
  domain   = "vpc"

  tags = {
    Name        = "chess-${var.environment}-eip"
    Environment = var.environment
  }
}


