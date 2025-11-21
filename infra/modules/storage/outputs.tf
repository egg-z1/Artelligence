output "storage_account_name" {
  description = "Storage Account 이름"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.main.id
}

output "images_container_name" {
  description = "이미지 컨테이너 이름"
  value       = azurerm_storage_container.images.name
}

output "thumbnails_container_name" {
  description = "썸네일 컨테이너 이름"
  value       = azurerm_storage_container.thumbnails.name
}

output "primary_blob_endpoint" {
  description = "기본 Blob 엔드포인트"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_connection_string" {
  description = "기본 연결 문자열"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "storage_connection_string" {
  description = "Storage Account 연결 문자열"
  value       = azurerm_storage_account.main.primary_connection_string
}
