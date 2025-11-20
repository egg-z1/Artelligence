# dev 환경은 prod와 동일한 변수 사용
# prod/variables.tf를 참조하거나 심볼릭 링크 생성

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "artelligence"
}

variable "environment" {
  description = "환경 이름 (dev, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure 리전"
  type        = string
  default     = "koreacentral"
}

variable "openai_location" {
  description = "Azure OpenAI 리전 (DALL-E 3 지원)"
  type        = string
  default     = "swedencentral"
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "Artelligence"
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

variable "backend_container_image" {
  description = "백엔드 컨테이너 이미지"
  type        = string
  default     = "ghcr.io/egg-z1/artelligence:latest"
}

variable "container_cpu" {
  description = "컨테이너 CPU"
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "컨테이너 메모리"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "최소 레플리카 수"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "최대 레플리카 수"
  type        = number
  default     = 2
}

variable "allowed_cors_origins" {
  description = "허용된 CORS 오리진"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "로그 보관 기간 (일)"
  type        = number
  default     = 7
}

variable "alert_email" {
  description = "알림 받을 이메일 주소"
  type        = string
}

variable "lifecycle_delete_after_days" {
  description = "오래된 Blob 자동 삭제 기간 (일)"
  type        = number
  default     = 30
}

variable "openai_api_key" {
  description = "OpenAI API Key (optional, can be null if auto-generated)"
  type        = string
  default     = null
}
