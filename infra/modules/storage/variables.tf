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
  description = "환경"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "container_app_principal_id" {
  description = "Container App의 Managed Identity Principal ID"
  type        = string
  default     = null
}

variable "allowed_cors_origins" {
  description = "허용할 CORS Origin 목록"
  type        = list(string)
  default = [
    "https://www.artelligence.shop",
    "https://artelligence.shop",
    "http://localhost:8080",
  ]
}

variable "delete_retention_days" {
  description = "Blob 삭제 보존 기간(일)"
  type        = number
  default     = 7
}

variable "lifecycle_delete_after_days" {
  description = "오래된 Blob 자동 삭제 기간(일)"
  type        = number
  default     = 90
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}
