output "chess_server_public_ip" {
  value = aws_instance.chess_server.public_ip
  description = "Public IP address of the Chess App Server"
}

