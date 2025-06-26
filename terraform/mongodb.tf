resource "aws_instance" "mongo" {
  count                  = var.mongo_count
  ami                    = var.mongo_ami
  instance_type          = "t3.micro"
  subnet_id              = element([aws_subnet.private1.id, aws_subnet.private2.id], count.index % 2)
  vpc_security_group_ids = [aws_security_group.mongo.id]
  key_name               = var.ssh_key_name
  tags = { Name = "mongo-${count.index + 1}" }
}