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

output "subnet_ids" {
  description = "Subnet IDs by purpose"
  value       = merge({ for name, subnet in azurerm_subnet.primary : name => subnet.id }, { app_functions = azurerm_subnet.app_functions.id })
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs by service"
  value       = { for name, zone in azurerm_private_dns_zone.primary : name => zone.id }
}
