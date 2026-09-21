locals {
  name = "rg-primary"
}

module "resource_group_primary" {
  source   = "../../Modules/ResourceGroup"
  name     = local.name
  location = var.location
}