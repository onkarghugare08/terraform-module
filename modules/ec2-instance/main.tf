# Key Pair
resource "aws_key_pair" "my_key_pair" {
  key_name   = "terra-key"
  public_key = file("${path.module}/terra-key.pub")
}


resource "aws_instance" "this" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = aws_key_pair.my_key_pair.key_name

   root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-server-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
  }
}
