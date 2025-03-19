resource "aws_instance" "chess_server" {
  ami             = "ami-08b5b3a93ed654d19"  # Amazon Linux 2 AMI (Update this to your region)
  instance_type   = "t3.micro"
  key_name        = aws_key_pair.chess_key.key_name
  security_groups = [aws_security_group.chess_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker git
    sudo systemctl start docker
    sudo systemctl enable docker

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Clone your chess app repository
    git clone https://github.com/akshatsri47/Chess.git
    cd /Chess

    # Start the Chess App using Docker Compose
    sudo docker-compose build
    sudo docker-compose up
  EOF

  tags = {
    Name = "Chess-App-Server"
  }
}

