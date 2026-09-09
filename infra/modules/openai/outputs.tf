output "endpoint" {
  description = "OpenAI 엔드포인트"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "cognitive_account_id" {
  description = "OpenAI Cognitive Account ID"
  value       = azurerm_cognitive_account.openai.id
}

output "image_deployment_name" {
  description = "GPT Image 1 Mini 배포 이름"
  value       = azurerm_cognitive_deployment.image.name
}

output "primary_access_key" {
  description = "Azure OpenAI 계정의 primary key"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}
