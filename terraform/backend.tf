terraform {
  backend "s3" {
    bucket = "ahmed-terraform-state-bucket"
    key    = "manara/project-2/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}