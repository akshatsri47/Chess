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

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-lts-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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

# Key Pair for SSH access
resource "aws_key_pair" "chess_key" {
  key_name   = "chess-${var.environment}-key"
  public_key = var.public_key
}

# EC2 Instance
resource "aws_instance" "chess_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = aws_key_pair.chess_key.key_name
  vpc_security_group_ids = [aws_security_group.chess_sg.id]

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

# Outputs
output "instance_ip" {
  description = "Public IP address of the Chess application instance"
  value       = aws_eip.chess_eip.public_ip
}

output "instance_id" {
  description = "ID of the Chess application instance"
  value       = aws_instance.chess_app.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.chess_sg.id
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_eip.chess_eip.public_ip}:5173"
}

output "backend_websocket_url" {
  description = "Backend WebSocket URL"
  value       = "ws://${aws_eip.chess_eip.public_ip}:8181"
}

