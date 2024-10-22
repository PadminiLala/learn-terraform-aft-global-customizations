// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.policies)
  policy_id = contains(keys(var.policy_id), "${var.policies_directory_name}/${each.value}.json") ? var.policy_id["${var.policies_directory_name}/${each.value}.json"].id : null
  target_id = var.ou
}
