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
