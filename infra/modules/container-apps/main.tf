resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1

  tags = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-${var.environment}-env"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}

resource "azurerm_container_app" "backend" {
  name                         = "${var.project_name}-${var.environment}-backend"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "artelligence-backend"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory
      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }

      env {
        name        = "AZURE_OPENAI_API_KEY"
        secret_name = "openai-api-key"
      }

      env {
        name        = "AZURE_STORAGE_CONNECTION_STRING"
        secret_name = "storage-connection-string"
      }

      env {
        name  = "DALLE_DEPLOYMENT_NAME"
        value = "dall-e-3"
      }

      env {
        name  = "CONTAINER_NAME"
        value = "generated-images"
      }

      env {
        name  = "LOG_LEVEL"
        value = var.environment == "prod" ? "INFO" : "DEBUG"
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = 10
    }
  }

  secret {
    name                = "openai-api-key"
    key_vault_secret_id = var.openai_api_key_secret_uri
    identity            = var.user_assigned_identity_id
  }

  secret {
    name                = "storage-connection-string"
    key_vault_secret_id = var.storage_connection_string_uri
    identity            = var.user_assigned_identity_id
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = var.tags
}
