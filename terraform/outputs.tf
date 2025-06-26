output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}
output "mongo_private_ips" {
  value = aws_instance.mongo[*].private_ip
}