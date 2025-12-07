# 🧠 Artelligence Backend API

**Artelligence**의 핵심 로직을 담당하는 백엔드 서버입니다.
**FastAPI** 프레임워크를 기반으로 구축되었으며, Azure OpenAI(DALL-E 3)를 이용한 이미지 생성과 Azure Blob Storage를 이용한 이미지 저장/관리 기능을 제공합니다.

* [🔗 client README](https://github.com/egg-z1/Artelligence/tree/main/client/artelligence)
* [🔗 infra README](https://github.com/egg-z1/Artelligence/tree/main/infra)

## 🛠️ Tech Stack

- **Language:** Python 3.9.6
- **Framework:** FastAPI
- **AI Model:** Azure OpenAI (DALL-E 3)
- **Storage:** Azure Blob Storage
- **Container:** Docker & Docker Compose
- **Monitoring:** Prometheus & Grafana

## 📂 폴더 구조 (Project Structure)

```bash
backend/
├── main.py                # FastAPI 앱 진입점 (라우팅, 설정)
├── config.py              # 환경 변수 및 앱 설정 관리
├── services/              # 핵심 비즈니스 로직
│   ├── image_generator.py # Azure OpenAI DALL-E 3 연동
│   └── storage_service.py # Azure Blob Storage 연동
├── monitoring/            # 모니터링 설정
│   ├── prometheus.yml     # Prometheus 설정 파일
│   └── grafana/           # Grafana 대시보드 설정
├── Dockerfile             # 백엔드 이미지 빌드 설정
├── docker-compose.yml     # 로컬 실행 및 모니터링 스택 실행
└── requirements.txt       # Python 의존성 목록
```

## 🚀 시작하기 (Getting Started)

### 1\. 사전 요구 사항

- Python 3.9.6 이상
- Docker & Docker Compose (선택 사항)

### 2\. 가상 환경 설정 및 의존성 설치

```bash
# 가상 환경 생성 (venv 폴더가 이미 있다면 생략 가능)
python -m venv venv

# 가상 환경 활성화
# Mac/Linux:
source venv/bin/activate
# Windows:
# .\venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt
```

### 3\. 환경 변수 설정 (.env)

`backend` 폴더 루트에 `.env` 파일을 생성하고 다음 정보를 입력하세요.
_(인프라 배포 시 출력된 `terraform output` 값을 참고하세요)_

```env
# Azure OpenAI 설정
AZURE_OPENAI_API_KEY=your_api_key
AZURE_OPENAI_ENDPOINT=https://your-resource-name.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=dall-e-3
AZURE_OPENAI_API_VERSION=2024-02-01

# Azure Storage 설정
AZURE_STORAGE_CONNECTION_STRING=your_connection_string
AZURE_STORAGE_CONTAINER_NAME=generated-images
AZURE_STORAGE_ACCOUNT_NAME=your_storage_account_name
AZURE_STORAGE_ACCOUNT_KEY=your_storage_account_key

# CORS 설정 (프론트엔드 도메인)
ALLOWED_ORIGINS=["https://www.artelligence.shop","http://localhost:8080"]
```

### 4\. 로컬 서버 실행

```bash
# uvicorn을 사용하여 서버 실행 (개발 모드)
uvicorn main:app --reload --port 8000
```

서버가 실행되면 `http://localhost:8000`에서 접근 가능합니다.

---

## 📖 API 문서 (Swagger UI)

서버가 실행 중일 때, 브라우저에서 다음 주소로 접속하면 API 문서를 확인하고 테스트할 수 있습니다.

- **Swagger UI:** [http://localhost:8000/docs](https://www.google.com/search?q=http://localhost:8000/docs)
- **ReDoc:** [http://localhost:8000/redoc](https://www.google.com/search?q=http://localhost:8000/redoc)

### 주요 엔드포인트

| Method   | Endpoint                         | 설명                           |
| :------- | :------------------------------- | :----------------------------- |
| `GET`    | `/health`                        | 서버 상태 확인                 |
| `POST`   | `/api/v1/generate`               | 텍스트 프롬프트로 이미지 생성  |
| `GET`    | `/api/v1/images`                 | 생성된 이미지 갤러리 목록 조회 |
| `GET`    | `/api/v1/images/{image_id:path}` | 특정 이미지 상세 정보 조회     |
| `DELETE` | `/api/v1/images/{image_id:path}` | 이미지 삭제                    |

---

## 🐳 Docker 실행 (Container)

### Docker 이미지 빌드 및 실행

```bash
# 이미지 빌드
docker build -t artelligence-backend .

# 컨테이너 실행
docker run -d -p 8000:8000 --env-file .env artelligence-backend
```

### Docker Compose (모니터링 포함)

백엔드 서버와 함께 Prometheus, Grafana를 한 번에 실행합니다.

```bash
docker-compose up -d
```

- **Backend:** `http://localhost:8000`
- **Prometheus:** `http://localhost:9090`
- **Grafana:** `http://localhost:3000` (기본 계정: admin / admin)

---

## 🔍 테스트 (Testing)

`test_api.py`를 실행하여 API가 정상 작동하는지 확인할 수 있습니다.

```bash
python test_api.py
```

---

## 📝 개발자 노트

- **라우팅 주의:** 이미지 ID에 슬래시(`/`)가 포함되므로, FastAPI 경로 매개변수 설정 시 `:path` 옵션을 사용해야 합니다. (예: `{image_id:path}`)
- **CORS:** 프로덕션 배포 시 `main.py`의 `allow_origins` 목록에 실제 프론트엔드 도메인이 포함되어 있는지 확인해야 합니다.
