terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.52"
    }
  }
}
provider "aws" {
  profile = var.profile
  region  = "us-east-1"
}