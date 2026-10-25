output "instance_id" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.this.*.id
}

output "public_ip" {
  description = "List of Public IPs"
  value       = aws_instance.this.*.public_ip
}
