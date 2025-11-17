# Artelligence Backend

AI 기반 소설 장면 이미지 생성 서비스의 백엔드 API

## 📋 목차

- [기술 스택](#기술-스택)
- [주요 기능](#주요-기능)
- [시작하기](#시작하기)
- [API 문서](#api-문서)
- [배포](#배포)
- [모니터링](#모니터링)

## 🛠 기술 스택

- **Framework**: FastAPI 0.109.0
- **Language**: Python 3.11
- **AI Service**: Azure OpenAI (DALL-E 3)
- **Storage**: Azure Blob Storage
- **Authentication**: Azure Key Vault
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Azure Container Apps

## ✨ 주요 기능

### 1. 이미지 생성

- Azure OpenAI DALL-E 3를 활용한 고품질 이미지 생성
- 프롬프트 기반 실시간 이미지 생성
- 다양한 크기 및 스타일 지원 (1024x1024, 1792x1024, 1024x1792)

### 2. 이미지 저장 및 관리

- Azure Blob Storage를 통한 안전한 이미지 저장
- 날짜별 폴더 구조로 체계적인 관리
- SAS 토큰 기반 보안 URL 생성

### 3. 실시간 통신

- WebSocket을 통한 이미지 생성 진행 상황 실시간 전송
- 비동기 처리로 높은 성능 보장

### 4. 모니터링

- Prometheus를 통한 메트릭 수집
- Grafana 대시보드로 시각화
- 헬스체크 엔드포인트

## 🚀 시작하기

### 필수 요구사항

- Python 3.11+
- Azure 계정 및 다음 리소스:
  - Azure OpenAI Service
  - Azure Blob Storage
  - Azure Key Vault (선택사항)

### 로컬 환경 설정

1. **저장소 클론**

```bash
git clone https://github.com/your-org/artelligence-backend.git
cd artelligence-backend
```

2. **가상 환경 생성 및 활성화**

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

3. **의존성 설치**

```bash
pip install -r requirements.txt
```

4. **환경 변수 설정**

```bash
cp .env.example .env
# .env 파일을 편집하여 Azure 리소스 정보 입력
```

5. **애플리케이션 실행**

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

6. **API 문서 확인**

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Docker로 실행

```bash
# Docker Compose로 실행
docker-compose up -d

# 로그 확인
docker-compose logs -f backend

# 서비스 중지
docker-compose down
```

## 📚 API 문서

### 주요 엔드포인트

#### 1. 헬스체크

```http
GET /health
```

서비스 상태 확인

#### 2. 이미지 생성

```http
POST /api/v1/generate
Content-Type: application/json

{
  "prompt": "어둠 속에서 빛나는 달빛 아래 고요한 호수",
  "size": "1024x1024",
  "quality": "standard",
  "style": "vivid"
}
```

**응답 예시:**

```json
{
  "image_id": "550e8400-e29b-41d4-a716-446655440000",
  "image_url": "https://...",
  "blob_url": "https://yourstorage.blob.core.windows.net/...",
  "prompt": "어둠 속에서 빛나는 달빛 아래 고요한 호수",
  "created_at": "2024-03-15T10:30:00Z",
  "status": "completed"
}
```

#### 3. 이미지 목록 조회

```http
GET /api/v1/images?limit=20&offset=0
```

#### 4. 특정 이미지 조회

```http
GET /api/v1/images/{image_id}
```

#### 5. 이미지 삭제

```http
DELETE /api/v1/images/{image_id}
```

#### 6. WebSocket 연결

```javascript
const ws = new WebSocket("ws://localhost:8000/ws/client-123");

ws.onopen = () => {
  ws.send(
    JSON.stringify({
      action: "generate",
      prompt: "신비로운 숲속의 작은 오두막",
      size: "1024x1024",
    })
  );
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log(data.status); // processing, saving, completed, error
};
```

## 🏗 프로젝트 구조

```
artelligence-backend/
├── main.py                 # FastAPI 애플리케이션 진입점
├── config.py              # 설정 관리
├── requirements.txt       # Python 의존성
├── Dockerfile            # Docker 이미지 빌드
├── docker-compose.yml    # Docker Compose 설정
├── .env.example         # 환경 변수 템플릿
├── services/
│   ├── image_generator.py    # 이미지 생성 서비스
│   └── storage_service.py    # Azure Blob Storage 서비스
├── monitoring/
│   ├── prometheus.yml        # Prometheus 설정
│   └── grafana/             # Grafana 대시보드
├── terraform/               # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── .github/
    └── workflows/
        └── deploy.yml       # CI/CD 파이프라인
```

## 🔐 보안

### Azure Key Vault 사용

환경 변수 대신 Azure Key Vault를 사용하려면:

1. `.env` 파일에서 Key Vault URL 설정:

```bash
AZURE_KEY_VAULT_URL=https://your-keyvault.vault.azure.net/
USE_KEY_VAULT=true
```

2. Key Vault에 시크릿 저장:

```bash
az keyvault secret set --vault-name your-keyvault --name azure-openai-api-key --value "your-key"
az keyvault secret set --vault-name your-keyvault --name azure-storage-account-key --value "your-key"
```

3. Managed Identity 권한 부여:

```bash
az keyvault set-policy --name your-keyvault \
  --object-id <managed-identity-object-id> \
  --secret-permissions get list
```

## 📊 모니터링

### Prometheus 메트릭

- **활성 WebSocket 연결 수**
- **API 요청 수 및 응답 시간**
- **이미지 생성 성공/실패율**
- **저장소 사용량**

### Grafana 대시보드

1. 브라우저에서 http://localhost:3000 접속
2. 기본 계정으로 로그인 (admin/admin)
3. Artelligence 대시보드 확인

## 🚢 배포

### Azure Container Apps 배포

1. **Terraform으로 인프라 생성**

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

2. **GitHub Actions로 자동 배포**

```bash
# .github/workflows/deploy.yml 설정 후
git push origin main
```

3. **수동 배포**

```bash
# Docker 이미지 빌드
docker build -t artelligence-backend:latest .

# Azure Container Registry에 푸시
az acr login --name yourregistry
docker tag artelligence-backend:latest yourregistry.azurecr.io/artelligence-backend:latest
docker push yourregistry.azurecr.io/artelligence-backend:latest

# Container App 업데이트
az containerapp update \
  --name artelligence-backend \
  --resource-group artelligence-rg \
  --image yourregistry.azurecr.io/artelligence-backend:latest
```

## 🧪 테스트

```bash
# 단위 테스트 실행
pytest tests/

# 커버리지 확인
pytest --cov=. tests/
```

## 📝 환경 변수

| 변수명                            | 설명                      | 필수 | 기본값           |
| --------------------------------- | ------------------------- | ---- | ---------------- |
| `AZURE_OPENAI_ENDPOINT`           | Azure OpenAI 엔드포인트   | ✅   | -                |
| `AZURE_OPENAI_API_KEY`            | Azure OpenAI API 키       | ✅   | -                |
| `AZURE_STORAGE_CONNECTION_STRING` | Azure Storage 연결 문자열 | ✅   | -                |
| `AZURE_STORAGE_CONTAINER_NAME`    | Blob 컨테이너 이름        | ❌   | generated-images |
| `DEBUG`                           | 디버그 모드               | ❌   | false            |
| `LOG_LEVEL`                       | 로그 레벨                 | ❌   | INFO             |

## 🤝 기여

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

This project is licensed under the MIT License.

## 📞 문의

프로젝트 관련 문의: your-email@example.com

## 🙏 감사의 글

- Azure OpenAI Service
- FastAPI
- Python 커뮤니티
