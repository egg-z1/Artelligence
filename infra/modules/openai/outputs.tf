output "endpoint" {
  description = "Azure OpenAI Endpoint"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "openai_id" {
  description = "Azure OpenAI ID"
  value       = azurerm_cognitive_account.openai.id
}

output "api_key_secret_uri" {
  description = "OpenAI API Key Secret URI"
  value       = azurerm_key_vault_secret.openai_api_key.id
  sensitive   = true
}

output "dalle3_deployment_name" {
  description = "DALL-E 3 배포 이름"
  value       = azurerm_cognitive_deployment.dalle3.name
}

output "primary_access_key" {
  description = "Primary Access Key"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

output "custom_subdomain" {
  description = "Custom Subdomain"
  value       = azurerm_cognitive_account.openai.custom_subdomain_name
}