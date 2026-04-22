variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "Billing mode must be either PROVISIONED or PAY_PER_REQUEST"
  }
}

variable "read_capacity" {
  description = "Read capacity units (only used when billing_mode is PROVISIONED)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units (only used when billing_mode is PROVISIONED)"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags to apply to the DynamoDB table"
  type        = map(string)
  default     = {}
}
