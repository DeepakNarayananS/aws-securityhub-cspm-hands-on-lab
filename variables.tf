variable "aws_region" {
  description = "Single AWS Region for the lab. Default is Mumbai (ap-south-1)."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "This lab is intentionally scoped to ap-south-1 (Mumbai)."
  }
}

variable "auto_remediation_enabled" {
  description = "Enable the Security Hub custom action -> EventBridge -> Lambda remediation path."
  type        = bool
  default     = true
}
