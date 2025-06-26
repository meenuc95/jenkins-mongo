resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  tags = { Name = "bastion-host" }
}