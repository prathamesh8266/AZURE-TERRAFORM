data "azurerm_resource_group" "network" {
  name = "rg-network"
}

module "resource_group_primary" {
  source              = "../../Modules/Network"
  location            = data.azurerm_resource_group.network.location
  resource_group_name = data.azurerm_resource_group.network.name
}