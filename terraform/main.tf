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

locals {
  ami_id = "ami-0036347a8a8be83f1"
}

resource "aws_security_group" "chess_sg" {
  name_prefix = "chess-${var.environment}-"
  description = "Security group for Chess application"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_iam_role" "chess_instance_role" {
  name = "chess-${var.environment}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })

  tags = {
    Name        = "chess-${var.environment}-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "chess_ssm_policy" {
  role       = aws_iam_role.chess_instance_role.name
  policy_arn = "arn:aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "chess_instance_profile" {
  name = "chess-${var.environment}-instance-profile"
  role = aws_iam_role.chess_instance_role.name

  tags = {
    Name        = "chess-${var.environment}-instance-profile"
    Environment = var.environment
  }
}

resource "aws_instance" "chess_app" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.chess_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.chess_instance_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -e

    sudo yum update -y
    sudo yum install -y docker git

    sudo systemctl start docker
    sudo systemctl enable docker

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    git clone ${var.git_repo} /home/ec2-user/Chess
    cd /home/ec2-user/Chess
    git checkout ${var.branch}

    sudo /usr/local/bin/docker-compose build
    sudo /usr/local/bin/docker-compose up -d

    echo "$(date): User data script completed" >> /var/log/user-data.log
  EOF

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

resource "aws_eip" "chess_eip" {
  instance = aws_instance.chess_app.id
  domain   = "vpc"

  tags = {
    Name        = "chess-${var.environment}-eip"
    Environment = var.environment
  }
}

# Only define outputs once here
output "instance_ip" {
  description = "Public IP address of the Chess application instance"
  value       = aws_eip.chess_eip.public_ip
}

output "instance_id" {
  description = "ID of the Chess application instance"
  value       = aws_instance.chess_app.id
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_eip.chess_eip.public_ip}:5173"
}

output "backend_websocket_url" {
  description = "Backend WebSocket URL"
  value       = "ws://${aws_eip.chess_eip.public_ip}:8181"
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.chess_sg.id
}

output "ec2_connect_command" {
  description = "AWS EC2 Instance Connect command"
  value       = "aws ec2-instance-connect send-ssh-public-key --instance-id ${aws_instance.chess_app.id} --instance-os-user ec2-user --ssh-public-key file://~/.ssh/id_rsa.pub --region ${var.region}"
}

output "aws_console_url" {
  description = "AWS Console URL for this instance"
  value       = "https://console.aws.amazon.com/ec2/v2/home?region=${var.region}#ConnectToInstance:instanceId=${aws_instance.chess_app.id}"
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
