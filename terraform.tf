terraform {
  backend "s3" {
    bucket         = "bgenebucket"
    key            = "bostongene/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
  required_providers {
    aws = {
      version = ">=5.88.0"
    }
  }
}
