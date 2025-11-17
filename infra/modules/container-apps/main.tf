resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30 # 30일 -> 7일로 축소
  daily_quota_gb      = 1  # 일일 1GB 제한으로 비용 통제

  tags = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-${var.environment}-env"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  # infrastructure_subnet_id 제거 - Consumption Plan 사용 (VNet 통합 비용 절감)

  tags = var.tags
}

# Managed Identity
resource "azurerm_user_assigned_identity" "container_app" {
  name                = "${var.project_name}-${var.environment}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# Container App
resource "azurerm_container_app" "backend" {
  name                         = "${var.project_name}-${var.environment}-backend"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "artelligence-backend"
      image  = var.container_image
      cpu    = var.container_cpu    # 0.25 사용 권장
      memory = var.container_memory # 0.5Gi 사용 권장

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

      liveness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/health"

        initial_delay_seconds   = 10
        period_seconds          = 30
        timeout_seconds         = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/ready"

        initial_delay_seconds   = 5
        period_seconds          = 10
        timeout_seconds         = 3
        failure_count_threshold = 3
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
    identity            = azurerm_user_assigned_identity.container_app.id
  }

  secret {
    name                = "storage-connection-string"
    key_vault_secret_id = var.storage_connection_string_uri
    identity            = azurerm_user_assigned_identity.container_app.id
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }

    # cors {
    #   allowed_origins = var.allowed_cors_origins
    #   allowed_methods = ["GET", "POST", "OPTIONS"]
    #   allowed_headers = ["*"]
    #   max_age         = 3600
    # }
  }

  tags = var.tags
}
