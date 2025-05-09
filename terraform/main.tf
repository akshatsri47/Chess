provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_instance" "chess_app" {
  ami           = "ami-0c02fb55956c7d316"  # Example Ubuntu AMI for us-east-1
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y docker.io docker-compose
              git clone https://github.com/akshatsri47/Chess.git
              cd Chess
              docker-compose up -d
              EOF

  tags = {
    Name = "chess-server"
  }
}

output "instance_ip" {
  value = aws_instance.chess_app.public_ip
}

