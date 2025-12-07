# 프로젝트 개요
* **프로젝트명** : Artelligence
* **기간** : 25.08.15 - 25.12.31 (4개월)
* [🔗 client README](https://github.com/egg-z1/Artelligence/tree/main/client/artelligence)
* [🔗 server README](https://github.com/egg-z1/Artelligence/tree/main/backend)
* [🔗 infra README](https://github.com/egg-z1/Artelligence/tree/main/infra)
* **기획 의도** :
  > 머릿속에만 존재하던 소설 속 장면을 눈앞에 만들기
  - 소설을 읽으며 떠오르는 **인상적인 장면들의 말 한 줄, 묘사 한 문단에 담긴 감정을 눈으로 볼 수 있다면 어떨까**라는 생각에서 프로젝트가 시작됐습니다.
  - 텍스트 기반의 장면을 인공지능을 통해 시각화하는 경험을 제공하고자 합니다.
  
* **주요 기술**

| 구분 | 기술 스택 |
| --- | --- |
| **Frontend** | Flutter (Web), http, web_socket_channel, file_saver, universal_html, uuid, flutter_svg |
| **Backend** | FastAPI, Uvicorn, Pydantic, Azure OpenAI SDK (DALL·E 3), Azure Storage Blob SDK, Azure Identity SDK, asyncio, aiofiles, python-multipart, websockets |
| **Infrastructure** | Azure Application Gateway + WAF, Azure Container Apps, Azure OpenAI Service, Azure Blob Storage, Terraform (IaC), GitHub Actions (CI/CD) |
| **Monitoring & Security** | Azure Key Vault, Azure Monitor |

------

# 구성도
<img height="600" alt="image" src="https://github.com/user-attachments/assets/d67c3585-de1c-42a9-841f-de974fb6b565" />

------

# 서비스 흐름
> https://www.artelligence.shop 에서 직접 시연하실 수 있습니다.
1. 프롬프트 입력 및 옵션(크기/품질/스타일) 선택
2. Azure OpenAI(DALL·E 3)를 통한 이미지 생성
3. Azure Blob Storage에 이미지 저장
4. 결과 이미지 웹에 표시 및 목록에 추가
5. 이미지 클릭 시 상세 정보(프롬프트, 생성일, 용량) 확인

------

# 서비스 설명

### 주요 기능

| 기능 | 설명 |
| --- | --- |
| 프롬프트 입력 | 사용자가 묘사하고 싶은 장면을 자연어로 입력 |
| 이미지 생성 | Azure OpenAI의 DALL·E 3 모델이 해당 문장을 기반으로 이미지 생성 |
| 이미지 저장 | Azure Blob Storage에 생성된 이미지 저장 |
| 이미지 보기 | 생성 결과를 웹 페이지에서 시각적으로 확인 |
| 자동 배포 | GitHub Actions + Terraform으로 인프라 및 코드 자동 배포 |
| 모니터링 | Prometheus + Grafana를 통한 서비스 상태 확인 |
