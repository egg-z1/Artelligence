# Issue #66: artelligence.store 연결 절차

기존 `.shop` 도메인과 Azure 리소스를 유지하면서 `.store` 도메인을 추가한다. 이 문서는 적용 절차이며, 코드 변경만으로 DNS 등록이나 배포가 완료되지는 않는다.

## 가비아 DNS (`artelligence.store` 영역)

| 유형 | 호스트 | 값 |
| --- | --- | --- |
| CNAME | `api` | `artelligence-dev-backend.grayisland-85257e96.koreacentral.azurecontainerapps.io` |
| TXT | `asuid.api` | `B868BFE75A773B864BBDA385994BF860657529B4CD7BC12671835E2B6BF103C4` |
| CNAME | `www` | `blue-coast-0187cab00.7.azurestaticapps.net` |

값은 2026-11-06 Azure 리소스에서 읽기 전용으로 조회했다. `api` CNAME은 Container App의 기본 FQDN을 직접 가리켜야 관리형 인증서를 발급·갱신할 수 있다. 가비아 입력란에 도메인 접미사가 자동으로 붙는지 확인하고, 값에는 `https://`나 경로를 넣지 않는다. `artelligence.store` 루트(`@`)는 이번 Terraform 설정에 등록하지 않았다. 루트 접속이 필요하면 가비아 포워딩 또는 Azure Static Web Apps 루트 도메인 등록 방식을 별도로 결정한다. 현재 state의 `container_app_domain_verification_id` 출력은 수정 전 코드가 만든 잘못된 값이므로, 변경 적용 전에는 DNS 입력에 쓰지 않는다.

## 적용 순서

1. Azure 기본 FQDN과 기존 `.shop` DNS 대상, 현재 인증서 상태를 확인한다. 조회 목적은 CNAME 대상과 기존 서비스가 정상임을 확인하는 것이다.
2. 가비아에 위 CNAME·TXT를 추가한다. `.shop` 레코드는 유지한다. 루트에 CAA 레코드가 있다면 DigiCert 발급을 허용하는지 확인한다.
3. DNS 전파 후 `terraform plan`을 확인한다. 예상 변경은 `.store` 커스텀 도메인 두 개와 백엔드·Storage CORS 업데이트다. 기존 리소스 삭제·재생성이 있으면 적용을 멈추고 원인을 확인한다. 초기 plan에 있던 `Consumption` workload profile 제거와 Storage `network_rules` 추가는 현재 Azure 구성에 맞게 코드를 정리해 해소했다. 2026-11-06 재실행한 plan은 **2개 추가, 2개 제자리 변경, 삭제 0**이었다. 백엔드의 `ALLOWED_ORIGINS` 변경은 새 리비전을 만들 수 있다.
4. `terraform apply`로 도메인을 추가한다. 고정된 azurerm 4.54.0에서 Terraform은 호스트 이름 등록을 관리한다. `ignore_changes`는 인증서 발급 동작이 아니라, 다음 plan에서 별도로 설정한 인증서 바인딩을 되돌리지 않기 위한 것이다.
5. DNS 검증이 완료되면 아래 Azure CLI 명령으로 **관리형 인증서를 발급·바인딩**한다. Terraform이 이미 호스트 이름을 추가했으므로 `hostname add`는 반복하지 않는다. Azure에서 `api.artelligence.store`의 상태가 **Secured**인지 확인한다.

   ```bash
   az containerapp hostname bind \
     --hostname api.artelligence.store \
     --resource-group artelligence-dev-rg \
     --name artelligence-dev-backend \
     --environment artelligence-dev-env \
     --validation-method CNAME
   ```

6. 인증서 바인딩 뒤 `infra/environments/dev`에서 `terraform plan`을 **다시 실행**한다. 새 도메인의 인증서 바인딩을 되돌리거나 기존 `.shop` 도메인·인증서를 삭제·재생성하는 변경이 없어야 한다. workload profile·Storage 네트워크 규칙 차이가 다시 나타나면 원인을 확인하고 다음 적용 전에 plan을 재검토한다.
7. `https://api.artelligence.store/health`와 TLS 인증서, API·WebSocket 동작을 확인한다.
8. GitHub 저장소의 **Settings → Secrets and variables → Actions → Variables**에서 `ARTELLIGENCE_API_HOST=api.artelligence.store`로 설정한 뒤 프론트엔드 워크플로를 수동 실행한다. 같은 변수는 이후 push 자동 배포에도 계속 적용된다. 변수가 없으면 `.shop`이 기본값이다.
9. `https://www.artelligence.store`에서 CORS, 이미지 생성·목록·상세·삭제, WebSocket 상태 전달, 기존 이미지 데이터 접근을 확인한다.

## 관리 범위

azurerm 4.54.0의 `azurerm_container_app_custom_domain`은 사용자 보유 인증서의 ID와 바인딩 유형을 지정할 수 있다. Azure 관리형 인증서의 발급·바인딩을 완료하는 Terraform 리소스는 이 버전에서 확인되지 않아 위 CLI 단계를 별도로 둔다. 이 설정의 `ignore_changes`는 CLI 변경에 의한 Terraform 리소스 재생성을 막는다. Static Web Apps의 커스텀 도메인 인증서는 Azure가 제공하므로, 프론트엔드 쪽은 별도 CLI 인증서 바인딩이 필요하지 않다.

## 적용·검증 기록 (2026-11-07)

- 적용 전 `https://api.artelligence.shop/health`: TLS 검증 성공, HTTP 200, `healthy`.
- 적용 직전 plan: 도메인 2개 추가, 백엔드·Storage CORS 2개 변경, 삭제 0. 다른 변경 없음.
- Terraform 적용: 계획대로 2개 추가, 2개 변경, 삭제 0. Static Web Apps의 새 도메인 등록은 약 16분 42초 걸렸고, Azure 상태는 `Ready`.
- `az containerapp hostname bind --validation-method CNAME`: 새 API 관리형 인증서 발급·바인딩 성공. 기존 `.shop` 및 새 `.store` 모두 `SniEnabled`.
- 적용 후 새 `.store`와 기존 `.shop` API의 `/health`: 양쪽 모두 TLS 검증 성공, HTTP 200, `healthy`.
- 인증서 바인딩 후 `terraform plan -detailed-exitcode`: 종료 코드 0, `No changes`.
- 프론트엔드 API 주소 전환과 배포는 아직 실행하지 않음.

## 프론트엔드 전환 전 API 검증

- `https://api.artelligence.store/api/v1/images`: 기존 이미지 5건 조회 성공.
- 기존 이미지 `20260912/2cb26e46-32dc-4146-9352-1110f95fa553.png`: 상세 조회 성공.
- `wss://api.artelligence.store/ws/issue66-probe-*`: TLS 연결 및 HTTP 101 업그레이드 성공. 생성 메시지는 전송하지 않음.
- 이미지 생성은 표준 품질로 1건만 실행: `20261106/7f27c9da-47e7-4ef0-a705-63c3112dbd6a.png` (Issue 66 domain migration test). 기존 이미지는 삭제하지 않았고 테스트 이미지도 유지했다.
- 테스트 이미지 상세 조회, Blob URL HEAD 200, Storage CORS의 `Access-Control-Allow-Origin: https://www.artelligence.store` 확인.
- API의 `https://www.artelligence.store` preflight: HTTP 200 및 허용 오리진 확인.
- `.store` API·WebSocket 주소를 넣은 Flutter Web 릴리스 빌드 성공. 수동 배포 시 `chore/#66` 브랜치의 워크플로를 선택한다. 기본 브랜치에는 이미 `workflow_dispatch` 트리거가 있다.

## 복구

프론트엔드 문제가 생기면 `ARTELLIGENCE_API_HOST=api.artelligence.shop`으로 되돌린 뒤 워크플로를 다시 실행한다. 기존 `.shop` 도메인과 DNS는 새 주소 검증이 끝날 때까지 제거하지 않는다.
