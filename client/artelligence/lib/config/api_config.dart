class ApiConfig {
  // 로컬 개발 환경
  // static const String baseUrl = 'http://localhost:8000';
  // static const String wsUrl = 'ws://localhost:8000';

  // 프로덕션 환경 (Azure Container Apps)
  static const String baseUrl = 'https://api.artelligence.shop';
  static const String wsUrl = 'wss://api.artelligence.shop';

  // API 엔드포인트
  static const String healthEndpoint = '/health';
  static const String generateEndpoint = '/api/v1/generate';
  static const String imagesEndpoint = '/api/v1/images';
  static const String metricsEndpoint = '/metrics';

  // WebSocket 엔드포인트
  static String wsEndpoint(String clientId) => '/ws/$clientId';

  // 타임아웃 설정
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration generateTimeout = Duration(minutes: 3);

  // 기본 헤더
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // 전체 URL 생성
  static String getFullUrl(String endpoint) => '$baseUrl$endpoint';
  static String getWsUrl(String endpoint) => '$wsUrl$endpoint';
}
