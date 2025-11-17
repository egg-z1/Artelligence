variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전 (DALL-E 3 지원: swedencentral, eastus)"
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

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "dalle_version" {
  description = "DALL-E 모델 버전"
  type        = string
  default     = "3.0"
}

variable "dalle_capacity" {
  description = "DALL-E 배포 용량 (1K TPM)"
  type        = number
  default     = 1
}

variable "enable_diagnostics" {
  description = "진단 설정 활성화 여부"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  type        = string
  default     = null
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}