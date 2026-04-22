variable "tags" {
  description = "Tags to apply to Lambda function and IAM role resources"
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "The name of the Project"
}