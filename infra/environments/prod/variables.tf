variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "artelligence"
}

variable "environment" {
  description = "환경 이름 (dev, prod)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure 리전"
  type        = string
  default     = "koreacentral" # 한국 리전이 가장 저렴
}

variable "openai_location" {
  description = "Azure OpenAI 리전 (DALL-E 3 지원)"
  type        = string
  default     = "swedencentral" # DALL-E 3 지원하며 상대적으로 저렴
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "Artelligence"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

# 네트워킹
variable "vnet_address_space" {
  description = "VNet 주소 공간"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "appgw_subnet_prefix" {
  description = "Application Gateway 서브넷"
  type        = string
  default     = "10.0.1.0/24"
}

variable "container_apps_subnet_prefix" {
  description = "Container Apps 서브넷"
  type        = string
  default     = "10.0.2.0/23"
}

# Container Apps
variable "backend_container_image" {
  description = "백엔드 컨테이너 이미지"
  type        = string
  default     = "ghcr.io/egg-z1/artelligence-backend:latest"
}

variable "container_cpu" {
  description = "컨테이너 CPU"
  type        = number
  default     = 0.25 # 0.5 -> 0.25로 절감
}

variable "container_memory" {
  description = "컨테이너 메모리"
  type        = string
  default     = "0.5Gi" # 1Gi -> 0.5Gi로 절감
}

variable "min_replicas" {
  description = "최소 레플리카 수"
  type        = number
  default     = 0 # 1 -> 0으로 변경 (사용 없을 때 완전 중지)
}

variable "max_replicas" {
  description = "최대 레플리카 수"
  type        = number
  default     = 3 # 10 -> 3으로 제한
}

# Application Gateway
variable "appgw_capacity" {
  description = "Application Gateway 용량"
  type        = number
  default     = 2
}

variable "ssl_certificate_path" {
  description = "SSL 인증서 경로"
  type        = string
  sensitive   = true
}

variable "ssl_certificate_password" {
  description = "SSL 인증서 비밀번호"
  type        = string
  sensitive   = true
}

# CORS
variable "allowed_cors_origins" {
  description = "허용된 CORS 오리진"
  type        = list(string)
  default     = ["https://artelligence.com", "https://www.artelligence.com"]
}

# IP 화이트리스트 (필요시)
variable "allowed_ip_ranges" {
  description = "허용된 IP 범위"
  type        = list(string)
  default     = []
}

# 모니터링
variable "log_retention_days" {
  description = "로그 보관 기간 (일)"
  type        = number
  default     = 7 # 30 -> 7일로 축소
}

variable "alert_email" {
  description = "알림 받을 이메일 주소"
  type        = string
}

variable "lifecycle_delete_after_days" {
  type        = number
  description = "Number of days after which images will be deleted automatically"
  default     = 90
}
