resource "azurerm_virtual_network" "primary" {
  name                = "vnet-primary"
  location            = var.location
  resource_group_name = var.resource_group_name

  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "primary" {
  for_each = {
    app      = "10.0.0.0/22"
    database = "10.0.4.0/24"
    app_aks  = "10.0.8.0/22"
  }

  name                 = "snet-${replace(each.key, "_", "-")}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = [each.value]
}

# Azure Functions VNet integration requires a dedicated delegated subnet.
resource "azurerm_subnet" "app_functions" {
  name                 = "snet-app-functions"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.0.5.0/24"]

  delegation {
    name = "functions"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_private_dns_zone" "primary" {
  for_each = {
    postgres  = "privatelink.postgres.database.azure.com"
    keyvault  = "privatelink.vaultcore.azure.net"
    registry  = "privatelink.azurecr.io"
    functions = "privatelink.azurewebsites.net"
    blob      = "privatelink.blob.core.windows.net"
  }

  name                = each.value
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "primary" {
  for_each = azurerm_private_dns_zone.primary

  name                  = "link-vnet-primary-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.primary.id
  registration_enabled  = false
}
