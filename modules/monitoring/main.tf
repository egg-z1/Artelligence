# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "${var.project_name}-${var.environment}-alerts"
  resource_group_name = var.resource_group_name
  short_name          = substr(var.project_name, 0, 12)
  
  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
  
  tags = var.tags
}

# Container App - High CPU Alert
resource "azurerm_monitor_metric_alert" "container_cpu" {
  count               = var.enable_container_alerts ? 1 : 0
  name                = "${var.project_name}-${var.environment}-high-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_app_id]
  description         = "Alert when CPU usage exceeds threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "UsageNanoCores"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.cpu_threshold_percent
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = var.tags
}

# Container App - High Memory Alert
resource "azurerm_monitor_metric_alert" "container_memory" {
  count               = var.enable_container_alerts ? 1 : 0
  name                = "${var.project_name}-${var.environment}-high-memory"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_app_id]
  description         = "Alert when memory usage exceeds threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "WorkingSetBytes"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.memory_threshold_bytes
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = var.tags
}

# Container App - HTTP 5xx Errors
resource "azurerm_monitor_metric_alert" "container_errors" {
  count               = var.enable_container_alerts ? 1 : 0
  name                = "${var.project_name}-${var.environment}-http-errors"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_app_id]
  description         = "Alert on HTTP 5xx errors"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"
  
  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
    
    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = var.tags
}

# Storage Account - Availability Alert
resource "azurerm_monitor_metric_alert" "storage_availability" {
  count               = var.enable_storage_alerts && var.storage_account_id != null ? 1 : 0
  name                = "${var.project_name}-${var.environment}-storage-availability"
  resource_group_name = var.resource_group_name
  scopes              = [var.storage_account_id]
  description         = "Alert when storage availability drops"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = var.tags
}

# Budget Alert (비용 초과 방지)
resource "azurerm_consumption_budget_resource_group" "daily" {
  count             = var.enable_budget_alerts ? 1 : 0
  name              = "${var.project_name}-${var.environment}-daily-budget"
  resource_group_id = var.resource_group_id
  
  amount     = var.daily_budget_amount
  time_grain = "Monthly"
  
  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }
  
  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"
    
    contact_emails = [var.alert_email]
  }
  
  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"
    
    contact_emails = [var.alert_email]
  }
}