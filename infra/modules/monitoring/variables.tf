variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
}

variable "resource_group_id" {
  description = "리소스 그룹 ID"
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

variable "alert_email" {
  description = "알림 받을 이메일 주소"
  type        = string
}

variable "container_app_id" {
  description = "Container App ID"
  type        = string
}

variable "storage_account_id" {
  description = "Storage Account ID"
  type        = string
  default     = null
}

variable "enable_container_alerts" {
  description = "Container App 알림 활성화"
  type        = bool
  default     = true
}

variable "enable_storage_alerts" {
  description = "Storage 알림 활성화"
  type        = bool
  default     = true
}

variable "enable_budget_alerts" {
  description = "예산 알림 활성화"
  type        = bool
  default     = true
}

variable "cpu_threshold_percent" {
  description = "CPU 알림 임계값 (%)"
  type        = number
  default     = 80
}

variable "memory_threshold_bytes" {
  description = "메모리 알림 임계값 (bytes)"
  type        = number
  default     = 419430400 # 400MB
}

variable "daily_budget_amount" {
  description = "일일 예산 (USD)"
  type        = number
  default     = 10
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}