variable "region"            { default = "us-east-1" }
variable "vpc_cidr"          { default = "10.0.0.0/17" }
variable "public_cidr"       { default = "10.0.0.0/25" }
variable "private_cidr1"     { default = "10.0.16.0/23" }   # <-- FIXED
variable "private_cidr2"     { default = "10.0.18.0/23" }   # <-- FIXED
variable "az1"               { default = "us-east-1a" }
variable "az2"               { default = "us-east-1b" }
variable "ssh_key_name"      { default = "ubuntu-slave-jen" }
variable "bastion_ami"       { default = "ami-0a7d80731ae1b2435" }
variable "mongo_ami"         { default = "ami-0a7d80731ae1b2435" }
variable "mongo_count"       { default = 3 }
variable "aws_access_key" {}
variable "aws_secret_key" {}