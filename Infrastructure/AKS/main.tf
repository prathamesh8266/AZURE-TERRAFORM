data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "app_aks" {
  name                 = "snet-app-aks"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

data "azurerm_container_registry" "primary" {
  name                = "acr${replace(var.name_prefix, "-", "")}${substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)}"
  resource_group_name = data.azurerm_resource_group.primary.name
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${var.name_prefix}"
  resource_group_name = data.azurerm_resource_group.primary.name
  location            = data.azurerm_resource_group.primary.location
}

resource "azurerm_role_assignment" "aks_subnet" {
  scope                = data.azurerm_subnet.app_aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "primary" {
  name                = "aks-${var.name_prefix}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name
  dns_prefix          = "aks-${var.name_prefix}"

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = data.azurerm_subnet.app_aks.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  depends_on = [azurerm_role_assignment.aks_subnet]
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = data.azurerm_container_registry.primary.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.primary.kubelet_identity[0].object_id
}

output "aks_id" {
  value = azurerm_kubernetes_cluster.primary.id
}
