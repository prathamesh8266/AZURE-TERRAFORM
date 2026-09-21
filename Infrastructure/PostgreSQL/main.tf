data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "database" {
  name                 = "snet-database"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.primary.name
}

locals {
  suffix = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
}

resource "azurerm_postgresql_flexible_server" "primary" {
  name                          = "pg-${var.name_prefix}-${local.suffix}"
  location                      = data.azurerm_resource_group.primary.location
  resource_group_name           = data.azurerm_resource_group.primary.name
  version                       = "16"
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  storage_mb                    = 32768
  sku_name                      = var.sku_name
  backup_retention_days         = 7
  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "postgres" {
  name                = "pe-pg-${var.name_prefix}-${local.suffix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  subnet_id           = data.azurerm_subnet.database.id

  private_service_connection {
    name                           = "psc-pg-${var.name_prefix}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.primary.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.postgres.id]
  }
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.primary.fqdn
}
