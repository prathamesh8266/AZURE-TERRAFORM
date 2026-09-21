data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "app" {
  name                 = "snet-app"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_subnet" "app_functions" {
  name                 = "snet-app-functions"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_private_dns_zone" "functions" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = data.azurerm_resource_group.primary.name
}

locals {
  suffix = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
}

resource "azurerm_service_plan" "functions" {
  name                = "plan-func-${var.name_prefix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  os_type             = "Linux"
  sku_name            = "EP1"
}

resource "azurerm_storage_account" "functions" {
  for_each = var.function_apps

  name                     = "st${substr(replace(var.name_prefix, "-", ""), 0, 4)}${substr(md5(each.key), 0, 10)}${local.suffix}"
  resource_group_name      = data.azurerm_resource_group.primary.name
  location                 = data.azurerm_resource_group.primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_linux_function_app" "functions" {
  for_each = var.function_apps

  name                          = "func-${var.name_prefix}-${each.key}-${local.suffix}"
  location                      = data.azurerm_resource_group.primary.location
  resource_group_name           = data.azurerm_resource_group.primary.name
  service_plan_id               = azurerm_service_plan.functions.id
  storage_account_name          = azurerm_storage_account.functions[each.key].name
  storage_account_access_key    = azurerm_storage_account.functions[each.key].primary_access_key
  https_only                    = true
  public_network_access_enabled = false
  virtual_network_subnet_id     = data.azurerm_subnet.app_functions.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    vnet_route_all_enabled = true

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
  }
}

resource "azurerm_private_endpoint" "functions" {
  for_each = var.function_apps

  name                = "pe-func-${var.name_prefix}-${each.key}-${local.suffix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  subnet_id           = data.azurerm_subnet.app.id

  private_service_connection {
    name                           = "psc-func-${var.name_prefix}-${each.key}"
    private_connection_resource_id = azurerm_linux_function_app.functions[each.key].id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.functions.id]
  }
}

output "function_app_hostnames" {
  value = { for name, app in azurerm_linux_function_app.functions : name => app.default_hostname }
}
