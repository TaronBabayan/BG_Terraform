terraform {
  #If you want to store backend remotely, you should create s3 bucket and Dyanomo DB table with partition key LockID    
  # backend "s3" {
  #  bucket         = "your_bucket_name"
  #  key            = "project_name/terraform.tfstate"
  #  region         = "us-east-1"
  #  dynamodb_table = "terraform-state-lock"
  #}
  required_providers {
    aws = {
      version = ">=5.88.0"
    }
  }
}
