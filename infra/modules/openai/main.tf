resource "azurerm_cognitive_account" "openai" {
  name                  = "${var.project_name}-${var.environment}-openai"
  resource_group_name   = var.resource_group_name
  location              = var.location
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "${var.project_name}${var.environment}openai"

  network_acls {
    default_action = "Allow"
  }

  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

# DALL-E 3 모델 배포
resource "azurerm_cognitive_deployment" "dalle3" {
  name                 = "dall-e-3"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "dall-e-3"
    version = "3.0"
  }

  sku {
    name     = "Standard"
    capacity = 1
  }
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "openai" {
  name                       = "${var.project_name}-${var.environment}-openai-diagnostics"
  target_resource_id         = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
