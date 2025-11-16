resource "azurerm_cognitive_account" "openai" {
  name                = "${var.project_name}-${var.environment}-openai"
  resource_group_name = var.resource_group_name
  location            = var.location # DALL-E 3: swedencentral, eastus 등
  kind                = "OpenAI"
  sku_name            = "S0"

  custom_subdomain_name = "${var.project_name}${var.environment}openai"

  network_acls {
    default_action = "Allow" # Private Endpoint 비용 절감
  }

  public_network_access_enabled = true

  tags = var.tags
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

  scale {
    type     = "Standard"
    capacity = 1
  }
}

# OpenAI API Key를 Key Vault에 저장
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id = var.key_vault_id
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

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
