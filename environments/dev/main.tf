# dev 환경은 prod와 거의 동일하되, backend 설정만 다름
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
    key                  = "dev.terraform.tfstate" # dev 환경용 state 파일
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

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}-${var.environment}-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

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

  lifecycle_delete_after_days = var.lifecycle_delete_after_days

  tags = var.common_tags

  container_app_principal_id = module.container_apps.user_assigned_identity_principal_id
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "myproject-dev-logs"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
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

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# Container Apps 모듈
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

  allowed_cors_origins = var.allowed_cors_origins
  log_retention_days   = var.log_retention_days

  tags = var.common_tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id # Terraform이 사용하는 SP

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]
}


# Key Vault Access Policy
resource "azurerm_key_vault_access_policy" "container_app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.container_apps.container_app_principal_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]
}

# 모니터링 (간단한 버전)
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

output "developer_info" {
  description = "개발자를 위한 연결 정보"
  value = {
    backend_url      = "https://${module.container_apps.fqdn}"
    health_check_url = "https://${module.container_apps.fqdn}/health"
    docs_url         = "https://${module.container_apps.fqdn}/docs"
    storage_account  = module.storage.storage_account_name
    key_vault        = azurerm_key_vault.main.name
  }
}
