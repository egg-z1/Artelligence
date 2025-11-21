terraform {
  required_version = ">= 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.54.0"
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

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_key_vault" "main" {
  name                = "${var.project_name}-${var.environment}-kv"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-logs"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.common_tags
}

resource "azurerm_role_assignment" "terraform_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_user_assigned_identity" "backend" {
  name                = "${var.project_name}-${var.environment}-backend-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.common_tags
}

resource "azurerm_role_assignment" "container_app_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}

resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = module.openai.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.terraform_keyvault_admin]
}

resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = module.storage.storage_connection_string
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.terraform_keyvault_admin]
}

module "container_apps" {
  source              = "../../modules/container-apps"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  environment         = var.environment

  openai_endpoint               = module.openai.endpoint
  openai_api_key_secret_uri     = azurerm_key_vault_secret.openai_api_key.id
  storage_connection_string_uri = azurerm_key_vault_secret.storage_connection_string.id

  container_image      = var.backend_container_image
  container_cpu        = var.container_cpu
  container_memory     = var.container_memory
  min_replicas         = var.min_replicas
  max_replicas         = var.max_replicas
  allowed_cors_origins = var.allowed_cors_origins
  log_retention_days   = var.log_retention_days
  tags                 = var.common_tags

  user_assigned_identity_id = azurerm_user_assigned_identity.backend.id

  depends_on = [
    azurerm_key_vault_secret.openai_api_key,
    azurerm_key_vault_secret.storage_connection_string,
    azurerm_role_assignment.container_app_keyvault_secrets_user
  ]
}

module "storage" {
  source                      = "../../modules/storage"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  project_name                = var.project_name
  environment                 = var.environment
  key_vault_id                = azurerm_key_vault.main.id
  lifecycle_delete_after_days = var.lifecycle_delete_after_days
  tags                        = var.common_tags
  container_app_principal_id  = azurerm_user_assigned_identity.backend.principal_id

  depends_on = [azurerm_role_assignment.terraform_keyvault_admin]
}

module "openai" {
  source                     = "../../modules/openai"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.openai_location
  project_name               = var.project_name
  environment                = var.environment
  key_vault_id               = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  openai_api_key             = null
  tags                       = var.common_tags

  depends_on = [azurerm_role_assignment.terraform_keyvault_admin]
}

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

output "backend_url" {
  value       = "https://${module.container_apps.fqdn}"
  description = "백엔드 API URL"
}

output "storage_account_name" {
  value       = module.storage.storage_account_name
  description = "Storage Account 이름"
}

output "openai_endpoint" {
  value       = module.openai.endpoint
  description = "Azure OpenAI 엔드포인트"
}

output "key_vault_name" {
  value       = azurerm_key_vault.main.name
  description = "Key Vault 이름"
}

output "developer_info" {
  description = "개발자를 위한 연결 정보"
  value = {
    backend_url      = "https://${module.container_apps.fqdn}"
    health_check_url = "https://${module.container_apps.fqdn}/health"
    docs_url         = "https://${module.container_apps.fqdn}/docs"
    storage_account  = module.storage.storage_account_name
    key_vault        = azurerm_key_vault.main.name
    openai_endpoint  = module.openai.endpoint
  }
}

resource "azurerm_static_site" "frontend" {
  name                = "${var.project_name}-${var.environment}-frontend"
  resource_group_name = azurerm_resource_group.main.name
  location            = "East Asia"
  sku_tier            = "Free"
  sku_size            = "Free"

  tags = var.common_tags
}

output "static_web_app_api_key" {
  value     = azurerm_static_site.frontend.api_key
  sensitive = true
}

output "frontend_default_hostname" {
  value = azurerm_static_site.frontend.default_host_name
}
