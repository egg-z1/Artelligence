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

# gpt-image-1-mini 모델 배포
resource "azurerm_cognitive_deployment" "image" {
  name                 = "gpt-image-1-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-image-1-mini"
    version = "2025-10-06"
  }

  sku {
    name     = "GlobalStandard"
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
