# 🎨 Artelligence Frontend (Flutter Web)

**Artelligence**의 사용자 인터페이스(UI)를 담당하는 웹 애플리케이션입니다.
**Flutter Web**으로 개발되었으며, 사용자가 텍스트 프롬프트를 입력하면 실시간으로 이미지를 생성하고 갤러리에서 확인할 수 있는 직관적인 경험을 제공합니다.

* [🔗 server README](https://github.com/egg-z1/Artelligence/tree/main/backend)
* [🔗 infra README](https://github.com/egg-z1/Artelligence/tree/main/infra)

## 📱 Features (주요 기능)

- **이미지 생성:** 프롬프트 입력 및 옵션(크기, 품질, 스타일) 선택
- **실시간 상태 확인:** WebSocket을 통한 생성 단계별(대기/생성중/완료) 알림
- **갤러리:** 생성된 이미지 목록 조회 (Infinite Scroll 지원 구조)
- **이미지 미리보기:** 생성된 이미지 확대 보기 및 다운로드
- **반응형 디자인:** 다양한 화면 크기에 대응하는 UI (Pretendard 폰트 적용)

## 🛠️ Tech Stack

- **Framework:** Flutter 3.32.4 (Web)
- **Language:** Dart 3.8.1
- **State Management:** Provider
- **Networking:** HTTP, WebSocket (Real-time)
- **Deployment:** Azure Static Web Apps

## 📂 폴더 구조 (Project Structure)

```bash
lib/
├── config/                       # 앱 설정
│   ├── api_config.dart           # API 엔드포인트 및 타임아웃 설정
│   └── theme_config.dart         # 색상, 폰트 등 테마 설정
├── models/                       # 데이터 모델 (JSON Serialization)
│   └── image_model.dart          # 이미지 및 요청 객체 모델
├── providers/                    # 상태 관리 (Business Logic)
│   └── image_provider.dart       # 이미지 생성, 조회, 상태 관리 로직
├── services/                     # 외부 통신
│   ├── api_service.dart          # 백엔드 REST API 호출
│   └── websocket_service.dart    # 실시간 상태 수신
├── screens/                      # 전체 화면 페이지
│   └── home_screen.dart          # 메인 대시보드 화면
├── widgets/                      # 재사용 가능한 UI 컴포넌트
│   ├── gallery_grid.dart         # 이미지 그리드 뷰
│   ├── image_generator_form.dart # 프롬프트 입력 폼
│   ├── image_preview.dart        # 이미지 상세 보기
│   └── status_indicator.dart     # 진행 상태 표시바
└── main.dart                     # 앱 진입점
```
