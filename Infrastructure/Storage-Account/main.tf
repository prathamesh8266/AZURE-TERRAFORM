data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "app" {
  name                 = "snet-app"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.primary.name
}

locals {
  suffix = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
}

resource "azurerm_storage_account" "primary" {
  name                            = "st${substr(replace(lower(var.name_prefix), "-", ""), 0, 10)}${local.suffix}"
  resource_group_name             = data.azurerm_resource_group.primary.name
  location                        = data.azurerm_resource_group.primary.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-st-blob-${var.name_prefix}-${local.suffix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  subnet_id           = data.azurerm_subnet.app.id

  private_service_connection {
    name                           = "psc-st-blob-${var.name_prefix}"
    private_connection_resource_id = azurerm_storage_account.primary.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }
}

output "storage_account_name" {
  value = azurerm_storage_account.primary.name
}

output "blob_endpoint" {
  value = azurerm_storage_account.primary.primary_blob_endpoint
}
