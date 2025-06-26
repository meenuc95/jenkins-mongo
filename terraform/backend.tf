terraform {
  backend "s3" {
    bucket         = "my-unique-bucket-name500"
    key            = "mongodb/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}