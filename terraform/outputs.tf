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

output "ec2_connect_command" {
  description = "AWS EC2 Instance Connect command to connect to the instance"
  value       = "aws ec2-instance-connect send-ssh-public-key --instance-id ${aws_instance.chess_app.id} --instance-os-user ubuntu --ssh-public-key file://~/.ssh/id_rsa.pub --region ${var.region}"
}

output "aws_console_url" {
  description = "AWS Console URL to connect to the instance"
  value       = "https://console.aws.amazon.com/ec2/v2/home?region=${var.region}#ConnectToInstance:instanceId=${aws_instance.chess_app.id}"
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
