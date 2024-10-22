 // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "policies" {
}

variable "policy_id" {
}

variable "ou" {
}

variable "policies_directory_name" {
}
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"  // Provide a default or leave it required
}