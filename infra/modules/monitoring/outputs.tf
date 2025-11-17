output "action_group_id" {
  description = "Action Group ID"
  value       = azurerm_monitor_action_group.main.id
}

output "action_group_name" {
  description = "Action Group 이름"
  value       = azurerm_monitor_action_group.main.name
}