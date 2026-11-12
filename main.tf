terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ResourceGroup = var.resource_group_name
    }
  }
}

variable "region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-west-2"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
  default     = "resource-group-uvu-it3200-ansamalsharif"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name: 3-63 characters, lowercase letters, numbers, hyphens and dots."
  default     = "bucket-uvu-it3200-ansamalsharif"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters, lowercase letters, numbers, hyphens and dots, starting and ending with a letter or number."
  }
}

variable "container_name" {
  type        = string
  description = "Name of the private container prefix inside the bucket."
  default     = "container-uvu-it3200-ansamalsharif"
}

resource "aws_resourcegroups_group" "main" {
  name = var.resource_group_name

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "ResourceGroup"
          Values = [var.resource_group_name]
        }
      ]
    })
  }
}

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "https_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "https_only" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.https_only.json

  depends_on = [aws_s3_bucket_public_access_block.main]
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "blob_data_contributor" {
  name = "bucket-data-contributor"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.main.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["${var.container_name}/*"]
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.main.arn}/${var.container_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.blob_data_contributor.arn
}

resource "aws_iam_role" "app" {
  name = "role-uvu-it3200-ansamalsharif"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_group" "bucket_users" {
  name = "bucket-users"
}

resource "aws_iam_group_policy" "assume_app_role" {
  name  = "assume-app-role"
  group = aws_iam_group.bucket_users.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.app.arn
      }
    ]
  })
}

output "account_id" {
  description = "AWS account ID (equivalent of the tenant ID)."
  value       = data.aws_caller_identity.current.account_id
}

output "role_arn" {
  description = "Role ARN (equivalent of the application client ID)."
  value       = aws_iam_role.app.arn
}

output "role_id" {
  description = "Role unique ID (equivalent of the service principal object ID)."
  value       = aws_iam_role.app.unique_id
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = aws_resourcegroups_group.main.name
}

output "resource_group_arn" {
  description = "ARN of the resource group."
  value       = aws_resourcegroups_group.main.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.main.arn
}