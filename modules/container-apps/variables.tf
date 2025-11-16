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

variable "subnet_id" {
  description = "Container Apps 서브넷 ID (선택사항)"
  type        = string
  default     = null
}

variable "openai_endpoint" {
  description = "Azure OpenAI Endpoint"
  type        = string
}

variable "openai_api_key_secret_uri" {
  description = "OpenAI API Key Secret URI"
  type        = string
  sensitive   = true
}

variable "storage_connection_string_uri" {
  description = "Storage Connection String Secret URI"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "컨테이너 이미지"
  type        = string
}

variable "container_cpu" {
  description = "컨테이너 CPU (0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0)"
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "컨테이너 메모리 (0.5Gi, 1Gi, 1.5Gi, 2Gi, 3Gi, 4Gi)"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "최소 레플리카 수 (0으로 설정 시 scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "최대 레플리카 수"
  type        = number
  default     = 3
}

variable "target_port" {
  description = "컨테이너 포트"
  type        = number
  default     = 8000
}

variable "allowed_cors_origins" {
  description = "허용된 CORS 오리진"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "Log Analytics 보관 기간"
  type        = number
  default     = 7
}

variable "log_daily_quota_gb" {
  description = "Log Analytics 일일 쿼터 (GB)"
  type        = number
  default     = 1
}

variable "dalle_deployment_name" {
  description = "DALL-E 배포 이름"
  type        = string
  default     = "dall-e-3"
}

variable "images_container_name" {
  description = "이미지 저장 컨테이너 이름"
  type        = string
  default     = "generated-images"
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

variable "container_app_principal_id" {
  description = "User Assigned Identity principal ID to be used for role assignments"
  type        = string
  default     = null
}
