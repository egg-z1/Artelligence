# 비용 최적화를 위해 VNet은 선택적으로만 사용
# 기본적으로는 Container Apps Consumption Plan (VNet 없이) 사용

resource "azurerm_virtual_network" "main" {
  count               = var.enable_vnet ? 1 : 0
  name                = "${var.project_name}-${var.environment}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  
  tags = var.tags
}

resource "azurerm_subnet" "container_apps" {
  count                = var.enable_vnet ? 1 : 0
  name                 = "container-apps-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.container_apps_subnet_prefix]
  
  delegation {
    name = "container-apps-delegation"
    
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Outputs
output "vnet_id" {
  value = var.enable_vnet ? azurerm_virtual_network.main[0].id : null
}

output "container_apps_subnet_id" {
  value = var.enable_vnet ? azurerm_subnet.container_apps[0].id : null
}