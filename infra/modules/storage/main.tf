resource "azurerm_storage_account" "main" {
  name                     = "${var.project_name}${var.environment}sa"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Cool" # Hot 대신 Cool 사용으로 저장 비용 절감

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD", "POST", "PUT"]
      allowed_origins    = var.allowed_cors_origins
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }

    delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Allow" # Deny 대신 Allow로 변경 (Private Endpoint 비용 절감)
    bypass         = ["AzureServices"]
  }

  min_tls_version = "TLS1_2"

  tags = var.tags
}

resource "azurerm_storage_container" "images" {
  name                  = "generated-images"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "thumbnails" {
  name                  = "thumbnails"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Managed Identity for Container Apps
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.container_app_principal_id
}

# Connection string을 Key Vault에 저장
resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = azurerm_storage_account.main.primary_connection_string
  key_vault_id = var.key_vault_id
}
