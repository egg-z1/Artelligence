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
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

# -------------------------------
# 리소스 그룹
# -------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
  tags     = var.common_tags
}

# -------------------------------
# Key Vault
# -------------------------------
resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}-${var.environment}-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.common_tags
}

# -------------------------------
# Blob Storage 모듈
# -------------------------------
module "storage" {
  source                      = "../../modules/storage"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  project_name                = var.project_name
  environment                 = var.environment
  key_vault_id                = azurerm_key_vault.main.id
  lifecycle_delete_after_days = var.lifecycle_delete_after_days
  tags                        = var.common_tags
  container_app_principal_id  = module.container_apps.user_assigned_identity_principal_id
}

# -------------------------------
# Log Analytics
# -------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "myproject-dev-logs"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# -------------------------------
# Azure OpenAI 모듈
# -------------------------------
module "openai" {
  source                     = "../../modules/openai"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.openai_location
  project_name               = var.project_name
  environment                = var.environment
  key_vault_id               = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = var.common_tags
}

# ⚠️ OpenAI 계정이 soft-deleted 상태이면 먼저 Azure CLI로 purge 필요
# az cognitiveservices account purge --name artelligence-dev-openai --resource-group artelligence-dev-rg --location koreacentral

# -------------------------------
# Container Apps 모듈
# -------------------------------
module "container_apps" {
  source                        = "../../modules/container-apps"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  project_name                  = var.project_name
  environment                   = var.environment
  openai_endpoint               = module.openai.endpoint
  openai_api_key_secret_uri     = module.openai.api_key_secret_uri
  storage_connection_string_uri = module.storage.connection_string_secret_uri
  container_image               = var.backend_container_image
  container_cpu                 = var.container_cpu
  container_memory              = var.container_memory
  min_replicas                  = var.min_replicas
  max_replicas                  = var.max_replicas
  allowed_cors_origins          = var.allowed_cors_origins
  log_retention_days            = var.log_retention_days
  tags                          = var.common_tags
}

# -------------------------------
# Key Vault RBAC 역할 할당
# -------------------------------
# Container App용 (Get/List/Set)
resource "azurerm_role_assignment" "container_app_keyvault_secret_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.container_apps.container_app_principal_id
  depends_on           = [module.container_apps]
}

# Terraform SP용 (모든 Secret 작업 가능)
resource "azurerm_role_assignment" "terraform_keyvault_contributor" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# -------------------------------
# Key Vault Secret 생성
# -------------------------------
resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = module.storage.storage_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_role_assignment.terraform_keyvault_contributor,
    azurerm_role_assignment.container_app_keyvault_secret_user
  ]
}

# -------------------------------
# 모니터링
# -------------------------------
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

# -------------------------------
# Outputs
# -------------------------------
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
