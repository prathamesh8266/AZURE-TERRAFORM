data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "app" {
  name                 = "snet-app"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.primary.name
}

locals {
  suffix = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
}

resource "azurerm_key_vault" "primary" {
  name                          = "kv-${var.name_prefix}-${local.suffix}"
  location                      = data.azurerm_resource_group.primary.location
  resource_group_name           = data.azurerm_resource_group.primary.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  public_network_access_enabled = false
  soft_delete_retention_days    = 7
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.name_prefix}-${local.suffix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  subnet_id           = data.azurerm_subnet.app.id

  private_service_connection {
    name                           = "psc-kv-${var.name_prefix}"
    private_connection_resource_id = azurerm_key_vault.primary.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.keyvault.id]
  }
}

output "vault_uri" {
  value = azurerm_key_vault.primary.vault_uri
}
