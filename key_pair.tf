resource "aws_key_pair" "chess_key" {
  key_name   = "chess-key"
  public_key = file("~/.ssh/id_rsa.pub") # Ensure this key exists
}

