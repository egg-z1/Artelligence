terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "artelligence-tfstate-rg"
    storage_account_name = "artellitfstate"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

# 리소스 그룹
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
  
  tags = var.common_tags
}

# Key Vault (필수 시크릿 저장용)
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}-${var.environment}-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"  # premium 대신 standard
  
  soft_delete_retention_days = 7  # 최소값
  purge_protection_enabled   = false  # 개발 환경에서는 false
  
  tags = var.common_tags
}

# Blob Storage 모듈
module "storage" {
  source = "../../modules/storage"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  environment         = var.environment
  key_vault_id        = azurerm_key_vault.main.id
  
  tags = var.common_tags
}

# Azure OpenAI 모듈
module "openai" {
  source = "../../modules/openai"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = var.openai_location
  project_name        = var.project_name
  environment         = var.environment
  key_vault_id        = azurerm_key_vault.main.id
  
  tags = var.common_tags
}

# Container Apps 모듈 (VNet 없이)
module "container_apps" {
  source = "../../modules/container-apps"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  environment         = var.environment
  
  openai_endpoint               = module.openai.endpoint
  openai_api_key_secret_uri     = module.openai.api_key_secret_uri
  storage_connection_string_uri = module.storage.connection_string_secret_uri
  
  container_image  = var.backend_container_image
  container_cpu    = var.container_cpu
  container_memory = var.container_memory
  min_replicas     = var.min_replicas
  max_replicas     = var.max_replicas
  
  tags = var.common_tags
}

# Key Vault Access Policy for Container App Identity
resource "azurerm_key_vault_access_policy" "container_app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.container_apps.container_app_principal_id
  
  secret_permissions = [
    "Get",
    "List"
  ]
}

# 기본 모니터링 (Alert Action Group)
resource "azurerm_monitor_action_group" "main" {
  name                = "${var.project_name}-${var.environment}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "artelli"
  
  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }
  
  tags = var.common_tags
}

# CPU 사용률 알림 (비용 급증 방지)
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "${var.project_name}-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [module.container_apps.container_app_id]
  description         = "Alert when CPU usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "UsageNanoCores"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = var.common_tags
}

data "azurerm_client_config" "current" {}

# Outputs
output "backend_url" {
  value = "https://${module.container_apps.fqdn}"
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "openai_endpoint" {
  value = module.openai.endpoint
}