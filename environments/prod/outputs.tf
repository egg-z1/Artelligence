output "resource_group_name" {
  description = "리소스 그룹 이름"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "리소스 그룹 ID"
  value       = azurerm_resource_group.main.id
}

output "backend_url" {
  description = "백엔드 API URL"
  value       = "https://${module.container_apps.fqdn}"
}

output "backend_fqdn" {
  description = "백엔드 FQDN"
  value       = module.container_apps.fqdn
}

output "storage_account_name" {
  description = "Storage Account 이름"
  value       = module.storage.storage_account_name
}

output "storage_blob_endpoint" {
  description = "Storage Blob Endpoint"
  value       = module.storage.primary_blob_endpoint
}

output "images_container_name" {
  description = "이미지 컨테이너 이름"
  value       = module.storage.images_container_name
}

output "openai_endpoint" {
  description = "Azure OpenAI Endpoint"
  value       = module.openai.endpoint
}

output "openai_deployment_name" {
  description = "DALL-E 3 배포 이름"
  value       = module.openai.dalle3_deployment_name
}

output "key_vault_name" {
  description = "Key Vault 이름"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.container_apps.log_analytics_workspace_id
}

output "container_app_identity_principal_id" {
  description = "Container App Identity Principal ID"
  value       = module.container_apps.container_app_principal_id
}

# Frontend 배포를 위한 정보
output "frontend_config" {
  description = "Frontend 설정 정보"
  value = {
    api_endpoint = "https://${module.container_apps.fqdn}"
    environment  = var.environment
  }
}

# 개발자를 위한 연결 정보
output "developer_info" {
  description = "개발자를 위한 연결 정보"
  value = {
    backend_url           = "https://${module.container_apps.fqdn}"
    health_check_url      = "https://${module.container_apps.fqdn}/health"
    docs_url              = "https://${module.container_apps.fqdn}/docs"
    storage_account       = module.storage.storage_account_name
    key_vault             = azurerm_key_vault.main.name
    log_analytics         = module.container_apps.log_analytics_workspace_name
  }
}