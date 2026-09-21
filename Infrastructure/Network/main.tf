data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

module "network_primary" {
  source              = "../../Modules/Network"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
}

moved {
  from = module.resource_group_primary
  to   = module.network_primary
}

output "subnet_ids" {
  value = module.network_primary.subnet_ids
}

output "private_dns_zone_ids" {
  value = module.network_primary.private_dns_zone_ids
}
