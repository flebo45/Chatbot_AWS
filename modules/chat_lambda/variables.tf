variable "function_name" {
  description = "The name of the lambda function"
  type = string
}

variable "runtime" {
  description = "The runtime environment for the lambda function"
  type = string
  default = "python3.12"
}

variable "source_file" {
  description = "The path to the Python code file"
  type = string
}