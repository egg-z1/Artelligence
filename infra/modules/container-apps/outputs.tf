output "fqdn" {
  description = "Container App FQDN 주소"
  value       = azurerm_container_app.backend.ingress[0].fqdn
}

output "container_app_id" {
  description = "Container App 리소스 ID"
  value       = azurerm_container_app.backend.id
}

output "container_app_name" {
  description = "Container App 이름"
  value       = azurerm_container_app.backend.name
}

output "latest_revision_name" {
  description = "최신 리비전 이름"
  value       = azurerm_container_app.backend.latest_revision_name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace 리소스 ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace 이름"
  value       = azurerm_log_analytics_workspace.main.name
}

output "container_app_environment_id" {
  description = "Container App Environment 리소스 ID"
  value       = azurerm_container_app_environment.main.id
}

output "url" {
  description = "Container App 접속 URL"
  value       = "https://${azurerm_container_app.backend.ingress[0].fqdn}"
}
