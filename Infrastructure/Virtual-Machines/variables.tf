variable "name_prefix" {
  type    = string
  default = "primary"
}

variable "vm_count" {
  type    = number
  default = 2

  validation {
    condition     = var.vm_count >= 0 && var.vm_count == floor(var.vm_count)
    error_message = "vm_count must be a non-negative whole number."
  }
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "Pass the public SSH key using TF_VAR_ssh_public_key."
  type        = string
}
