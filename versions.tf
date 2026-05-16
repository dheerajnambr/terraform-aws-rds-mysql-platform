terraform {
  required_version = ">= 1.6.0"

  # S3 backend — configuration injected at init time via -backend-config flags.
  # No values are hardcoded here so this config is safe to commit.
  # CI/CD injects: bucket, key, region, encrypt=true
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
