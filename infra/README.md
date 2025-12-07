# 🏗️ Artelligence Infrastructure (IaC)

이 디렉토리는 **Artelligence** 서비스의 클라우드 인프라를 정의하고 관리하는 **Terraform** 코드를 담고 있습니다.
Azure Cloud 리소스를 코드로 관리(Infrastructure as Code)하여, 개발 환경을 일관성 있게 배포하고 관리합니다.

* [🔗 client README](https://github.com/egg-z1/Artelligence/tree/main/client/artelligence)
* [🔗 server README](https://github.com/egg-z1/Artelligence/tree/main/backend)
  
## 📂 폴더 구조

```bash
infra/
├── environments/          # 환경별 배포 구성
│   └── dev/               # 개발(Dev) 환경 설정 (main.tf, variables.tf 등)
└── modules/               # 재사용 가능한 리소스 모듈
    ├── container-apps/    # 백엔드 서버 (FastAPI)
    ├── monitoring/        # 모니터링
    ├── networking/        # (추후) vnet 추가 예정
    ├── openai/            # AI 이미지 생성 (DALL-E 3)
    └── storage/           # 이미지 저장소 (Blob Storage)
```

## 🛠️ 사전 요구 사항 (Prerequisites)

이 인프라를 배포하기 위해서는 다음 도구들이 설치되어 있어야 합니다.

- [Terraform](https://www.terraform.io/downloads) (v1.12.2 권장)
- [Azure CLI](https://www.google.com/search?q=https://docs.microsoft.com/ko-kr/cli/azure/install-azure-cli) (`az`)
- Azure 계정 및 활성화된 구독 (Subscription)

## 🚀 배포 가이드 (Quick Start)

터미널에서 `infra/environments/dev` 경로로 이동하여 진행합니다.

### 1\. Azure 로그인 및 구독 설정

```bash
az login
# 사용할 구독 ID 설정 (여러 구독이 있는 경우 필수)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2\. Terraform 초기화

프로젝트를 처음 시작하거나 모듈/프로바이더 버전이 변경되었을 때 실행합니다.

```bash
cd infra/environments/dev
terraform init -upgrade
```

### 3\. 환경 변수 설정 (`terraform.tfvars`)

보안이 필요한 값(이메일 등)은 `variables.tf`의 default 값을 비워두고, **`terraform.tfvars`** 파일을 생성하여 따로 관리합니다.
_(주의: `terraform.tfvars`는 `.gitignore`에 포함되어야 합니다.)_

**`infra/environments/dev/terraform.tfvars` 예시:**

```hcl
alert_email = "admin@example.com"
allowed_cors_origins = [
  "https://www.artelligence.shop",
  "https://artelligence.shop",
  "http://localhost:8080"
]
```

### 4\. 계획 확인 (Plan)

어떤 리소스가 생성, 변경, 삭제될지 미리 확인합니다.

```bash
terraform plan
```

### 5\. 인프라 배포 (Apply)

실제 Azure에 리소스를 생성합니다.

```bash
terraform apply
# 확인 메시지가 나오면 'yes' 입력
```

## ☁️ 주요 리소스 구성 (Architecture)

이 Terraform 코드는 다음과 Azure 리소스들을 자동으로 생성하고 연결합니다.

| 리소스 종류               | 역할                                                  | 모듈명            |
| :------------------------ | :---------------------------------------------------- | :---------------- |
| **Azure Container Apps**  | 백엔드 API 서버 (FastAPI) 호스팅, Serverless 컨테이너 | `container_apps`  |
| **Azure Static Web Apps** | 프론트엔드 (Flutter Web) 호스팅, 글로벌 CDN, 자동 SSL | `frontend` (root) |
| **Azure OpenAI**          | DALL-E 3 모델을 통한 이미지 생성 API                  | `openai`          |
| **Azure Blob Storage**    | 생성된 이미지 파일 영구 저장                          | `storage`         |
| **Azure Key Vault**       | API Key, DB 연결 문자열 등 비밀 정보 안전 관리        | root              |
| **Log Analytics**         | 서버 로그 수집 및 모니터링                            | root              |

## ⚠️ 주요 설정 및 트러블슈팅

### CORS 설정 (Cross-Origin Resource Sharing)

프론트엔드(`artelligence.shop`)에서 백엔드 API를 호출하기 위해 CORS 설정이 중요합니다.

- **Terraform:** `terraform.tfvars`의 `allowed_cors_origins` 변수에 도메인을 추가해야 합니다.
- **적용 시점:** `terraform apply` 후에는 **반드시 Container App을 재시작**해야 CORS 설정이 확실하게 적용됩니다.

### Provider 버전 호환성

`terraform init` 시 버전 락 파일 에러가 발생할 경우, 다음 명령어로 업그레이드하세요.

```bash
terraform init -upgrade
```

### 리소스 Import

이미 Azure Portal에서 수동으로 만든 리소스와 충돌이 날 경우, `terraform import` 명령어를 사용하여 상태(State)를 동기화해야 합니다.

---

### 📝 개발자 노트

- **`prod` 환경:** 현재는 `dev` 환경만 구성되어 있습니다. 추후 상용 배포 시 `environments/prod` 폴더를 생성하여 확장할 수 있습니다.
- **State 관리:** 현재 State 파일은 Azure Storage Account(`tfstate`)에 원격 저장되어 협업 시 충돌을 방지합니다.
