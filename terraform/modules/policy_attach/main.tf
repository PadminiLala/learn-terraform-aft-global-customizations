// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.policies)
  policy_id = contains(keys(var.policy_id), "${var.policies_directory_name}/${each.value}.json") ? var.policy_id["${var.policies_directory_name}/${each.value}.json"].id : null
  target_id = var.ou
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  // Use the appropriate version for your needs
    }
  }
}

// Declare the provider in the module
provider "aws" {
  // Optionally specify region or other configurations
  region = var.aws_region  // If you have a variable for the region
}