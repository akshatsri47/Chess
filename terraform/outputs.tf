# Output definitions for Terraform

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

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/chess-${var.environment}-key.pem ubuntu@${aws_eip.chess_eip.public_ip}"
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
