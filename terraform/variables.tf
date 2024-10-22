variable "controls" {
  type = list(object({
    control_names           = list(string)
    organizational_unit_ids = list(string)
  }))

  description = "Configuration of AWS Control Tower Guardrails for the whole organization"

  default = [
    {
      control_names = [
        "AWS-GR_EC2_VOLUME_INUSE_CHECK",
        "AWS-GR_ENCRYPTED_VOLUMES",
      ],
      organizational_unit_ids = ["ou-yg4k-d1e1mvce"],
    },
  ]
}
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "ou_list" {
    default = {
        "ou-yg4k-0fjg9s9p" = ["sandbox"]                #sandbox ou

    }
}

variable "policies_directory_name" {
  type    = string
  default = "policies"
}