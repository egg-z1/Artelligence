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
    ├── openai/            # AI 이미지 생성 (gpt-image-1-mini)
    └── storage/           # 이미지 저장소 (Blob Storage)
```

## ☁️ 주요 리소스 구성 (Architecture)

이 Terraform 코드는 다음과 Azure 리소스들을 자동으로 생성하고 연결합니다.

| 리소스 종류               | 역할                                                  | 모듈명            |
| :------------------------ | :---------------------------------------------------- | :---------------- |
| **Azure Container Apps**  | 백엔드 API 서버 (FastAPI) 호스팅, Serverless 컨테이너 | `container_apps`  |
| **Azure Static Web Apps** | 프론트엔드 (Flutter Web) 호스팅, 글로벌 CDN, 자동 SSL | `frontend` (root) |
| **Azure OpenAI**          | gpt-image-1-mini 모델을 통한 이미지 생성 API                  | `openai`          |
| **Azure Blob Storage**    | 생성된 이미지 파일 영구 저장                          | `storage`         |
| **Azure Key Vault**       | API Key, DB 연결 문자열 등 비밀 정보 안전 관리        | root              |
| **Log Analytics**         | 서버 로그 수집 및 모니터링                            | root              |

