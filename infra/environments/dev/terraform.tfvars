# 개발 환경 설정
project_name    = "artelligence"
environment     = "dev"
location        = "koreacentral"
openai_location = "swedencentral"

# 태그
common_tags = {
  Project     = "Artelligence"
  Environment = "Development"
  ManagedBy   = "Terraform"
}

# Container Apps 설정
backend_container_image = "ghcr.io/egg-z1/Artelligence-backend:dev"
container_cpu           = 0.25
container_memory        = "0.5Gi"
min_replicas            = 0  # Scale-to-zero
max_replicas            = 2

# CORS 설정 (개발 환경)
allowed_cors_origins = ["*"]

# 로그 보관
log_retention_days = 7

# 알림 이메일
alert_email = "kimfreedom25@gmail.com"

# Storage Lifecycle (개발 환경은 더 짧게)
lifecycle_delete_after_days = 30