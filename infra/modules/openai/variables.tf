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

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API Key (선택사항, null이면 자동 생성된 키 사용)"
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}
