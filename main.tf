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
   key            = "netology/terraform.tfstate"
   region         = "eu-west-2"
   dynamodb_table = "terraform-locks"
 }
}


locals {
 web_instance_type_map = {
   stage = "t2.micro"
   prod = "t3.micro"
 }
 web_instance_count_map = {
   stage = 1
   prod = 2
 }
}

resource "aws_instance" "test" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = local.web_instance_type_map[terraform.workspace]
  count = local.web_instance_count_map[terraform.workspace]

  tags = {
    Name = "testubuntu"
  }
}

locals {
 instances = {
   "t3.micro" = data.aws_ami.ubuntu.id
   "t2.micro" = data.aws_ami.ubuntu.id
 }
}

resource "aws_instance" "for_each" {
 for_each = local.instances
 ami = each.value
 instance_type = each.key

 lifecycle {
  create_before_destroy = true
 }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}