variable "name_prefix" {
  type    = string
  default = "primary"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}
