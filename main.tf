provider "aws" {
  region = "eu-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

terraform {
 backend "s3" {
   bucket         = "terraform-test-netology"
   encrypt        = true
   key            = "test/terraform.tfstate"
   region         = "eu-west-2"
   dynamodb_table = "terraform-locks"
 }
}

resource "aws_instance" "test" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "testubuntu"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
