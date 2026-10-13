terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Remote state would go in an S3 backend with locking. A lab that one person
  # creates and destroys in a day keeps local state on purpose.
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "editalis-cloud"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
