# 프로젝트 기본 설정
project_name = "artelligence"
environment  = "prod"
location     = "koreacentral"
openai_location = "swedencentral"  # DALL-E 3 지원 리전

# 태그
common_tags = {
  Project     = "Artelligence"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "your-team"
}

# Container Apps 설정 (비용 최적화)
backend_container_image = "ghcr.io/egg-z1/artelligence:latest"
container_cpu           = 0.25   # 최소 사양
container_memory        = "0.5Gi"
min_replicas           = 0       # Scale-to-zero
max_replicas           = 3

# CORS 설정
allowed_cors_origins = [
  "https://artelligence.com",
  "https://www.artelligence.com"
]

# 로그 보관 설정 (비용 절감)
log_retention_days = 7

# 알림 이메일
alert_email = "kimfreedom25@gmail.com"

# Storage Lifecycle (선택사항)
lifecycle_delete_after_days = 90  # 90일 이상 된 이미지 자동 삭제