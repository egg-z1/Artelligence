output "vnet_id" {
  description = "VNet ID"
  value       = var.enable_vnet ? azurerm_virtual_network.main[0].id : null
}

output "vnet_name" {
  description = "VNet 이름"
  value       = var.enable_vnet ? azurerm_virtual_network.main[0].name : null
}

output "container_apps_subnet_id" {
  description = "Container Apps 서브넷 ID"
  value       = var.enable_vnet ? azurerm_subnet.container_apps[0].id : null
}

output "container_apps_subnet_name" {
  description = "Container Apps 서브넷 이름"
  value       = var.enable_vnet ? azurerm_subnet.container_apps[0].name : null
}