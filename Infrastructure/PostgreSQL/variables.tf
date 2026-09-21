variable "name_prefix" {
  type    = string
  default = "primary"
}

variable "administrator_login" {
  type    = string
  default = "pgadmin"
}

variable "administrator_password" {
  description = "Set using TF_VAR_administrator_password; do not commit it."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}
