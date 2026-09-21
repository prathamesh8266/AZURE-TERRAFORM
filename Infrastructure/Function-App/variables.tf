variable "name_prefix" {
  type    = string
  default = "primary"
}

variable "function_apps" {
  description = "Function App names. Terraform for_each creates one app and storage account per name."
  type        = set(string)
  default     = ["api", "worker"]
}
