output "vnet_id" {
  description = "The ID of the VNet"
  value       = azurerm_virtual_network.primary.id
}

output "vnet_name" {
  description = "The name of the VNet"
  value       = azurerm_virtual_network.primary.name
}

output "vnet_address_space" {
  description = "The VNet address space"
  value       = azurerm_virtual_network.primary.address_space
}