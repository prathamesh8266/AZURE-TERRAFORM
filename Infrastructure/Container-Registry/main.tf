data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "app" {
  name                 = "snet-app"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_private_dns_zone" "registry" {
  name                = "privatelink.azurecr.io"
  resource_group_name = data.azurerm_resource_group.primary.name
}

locals {
  suffix = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
}

resource "azurerm_container_registry" "primary" {
  name                          = "acr${replace(var.name_prefix, "-", "")}${local.suffix}"
  resource_group_name           = data.azurerm_resource_group.primary.name
  location                      = data.azurerm_resource_group.primary.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "registry" {
  name                = "pe-acr-${var.name_prefix}-${local.suffix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  subnet_id           = data.azurerm_subnet.app.id

  private_service_connection {
    name                           = "psc-acr-${var.name_prefix}"
    private_connection_resource_id = azurerm_container_registry.primary.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.registry.id]
  }
}

output "registry_login_server" {
  value = azurerm_container_registry.primary.login_server
}
