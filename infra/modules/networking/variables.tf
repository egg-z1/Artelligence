variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, prod)"
  type        = string
}

variable "enable_vnet" {
  description = "VNet 활성화 여부 (비용 절감을 위해 기본 false)"
  type        = bool
  default     = false
}

variable "vnet_address_space" {
  description = "VNet 주소 공간"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "container_apps_subnet_prefix" {
  description = "Container Apps 서브넷 주소"
  type        = string
  default     = "10.0.2.0/23"
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}