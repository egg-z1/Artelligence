output "fqdn" {
  description = "Container App FQDN"
  value       = azurerm_container_app.backend.ingress[0].fqdn
}

output "container_app_id" {
  description = "Container App ID"
  value       = azurerm_container_app.backend.id
}

output "container_app_name" {
  description = "Container App 이름"
  value       = azurerm_container_app.backend.name
}

output "container_app_principal_id" {
  description = "Container App Managed Identity Principal ID"
  value       = azurerm_user_assigned_identity.container_app.principal_id
}

output "container_app_identity_id" {
  description = "Container App Managed Identity ID"
  value       = azurerm_user_assigned_identity.container_app.id
}

output "latest_revision_name" {
  description = "최신 리비전 이름"
  value       = azurerm_container_app.backend.latest_revision_name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace 이름"
  value       = azurerm_log_analytics_workspace.main.name
}

output "container_app_environment_id" {
  description = "Container App Environment ID"
  value       = azurerm_container_app_environment.main.id
}

output "url" {
  description = "Container App URL"
  value       = "https://${azurerm_container_app.backend.ingress[0].fqdn}"
}

output "user_assigned_identity_principal_id" {
  value = azurerm_user_assigned_identity.container_app.principal_id
}
