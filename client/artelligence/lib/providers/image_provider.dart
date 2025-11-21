import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/image_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

enum GenerationStatus { idle, processing, saving, completed, error }

class ImageProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  final Uuid _uuid = const Uuid();

  // 상태
  GenerationStatus _status = GenerationStatus.idle;
  String? _statusMessage;
  GeneratedImage? _currentImage;
  List<ImageItem> _galleryImages = [];
  bool _isServerHealthy = false;
  bool _isLoadingGallery = false;

  // Getters
  GenerationStatus get status => _status;
  String? get statusMessage => _statusMessage;
  GeneratedImage? get currentImage => _currentImage;
  List<ImageItem> get galleryImages => _galleryImages;
  bool get isServerHealthy => _isServerHealthy;
  bool get isLoadingGallery => _isLoadingGallery;
  bool get isGenerating =>
      _status == GenerationStatus.processing ||
      _status == GenerationStatus.saving;

  ImageProvider() {
    _initialize();
  }

  // 초기화
  Future<void> _initialize() async {
    await checkServerHealth();
    await loadGallery();
    await _setupWebSocket();
  }

  // 서버 헬스체크
  Future<void> checkServerHealth() async {
    try {
      final health = await _apiService.checkHealth();
      _isServerHealthy = health.isHealthy;
      notifyListeners();
    } catch (e) {
      _isServerHealthy = false;
      print('서버 헬스체크 실패: $e');
      notifyListeners();
    }
  }

  // WebSocket 설정
  Future<void> _setupWebSocket() async {
    try {
      final clientId = 'flutter-${_uuid.v4()}';
      await _wsService.connect(clientId);

      _wsService.messageStream?.listen((message) {
        _handleWebSocketMessage(message);
      });
    } catch (e) {
      print('WebSocket 설정 실패: $e');
    }
  }

  // WebSocket 메시지 처리
  void _handleWebSocketMessage(WebSocketMessage message) {
    switch (message.status) {
      case 'processing':
        _status = GenerationStatus.processing;
        _statusMessage = message.message ?? '이미지 생성 중...';
        break;
      case 'saving':
        _status = GenerationStatus.saving;
        _statusMessage = message.message ?? '이미지 저장 중...';
        break;
      case 'completed':
        _status = GenerationStatus.completed;
        _statusMessage = message.message ?? '이미지 생성 완료!';
        if (message.imageUrl != null) {
          _currentImage = GeneratedImage(
            imageId: message.imageId ?? '',
            imageUrl: message.imageUrl!,
            blobUrl: message.blobUrl,
            prompt: '',
            createdAt: DateTime.now().toIso8601String(),
            status: 'completed',
          );
        }
        loadGallery(); // 갤러리 새로고침
        break;
      case 'error':
        _status = GenerationStatus.error;
        _statusMessage = message.message ?? '오류가 발생했습니다';
        break;
    }
    notifyListeners();
  }

  // 이미지 생성 요청
  Future<void> generateImage({
    required String prompt,
    required String size,
    required String quality,
    required String style,
  }) async {
    try {
      _status = GenerationStatus.processing;
      _statusMessage = 'AI가 이미지를 그리고 있어요...';
      _currentImage = null;
      notifyListeners();

      final request = GenerationRequest(
        prompt: prompt,
        size: size,
        quality: quality,
        style: style,
      );

      final generatedImage = await _apiService.generateImage(request);

      _currentImage = generatedImage;
      _status = GenerationStatus.completed;
      _statusMessage = '이미지 생성이 완료되었습니다!';

      await loadGallery();
      notifyListeners();
    } catch (e) {
      _status = GenerationStatus.error;
      _statusMessage = '오류가 발생했습니다: ${e.toString()}';
      print('이미지 생성 에러: $e');
      notifyListeners();
    }
  }

  // 갤러리 로드
  Future<void> loadGallery({int limit = 12, int offset = 0}) async {
    try {
      _isLoadingGallery = true;
      notifyListeners();

      final response = await _apiService.getImages(
        limit: limit,
        offset: offset,
      );
      _galleryImages = response.images;

      _isLoadingGallery = false;
      notifyListeners();
    } catch (e) {
      print('갤러리 로드 실패: $e');
      _isLoadingGallery = false;
      notifyListeners();
    }
  }

  // 이미지 삭제
  Future<bool> deleteImage(String imageId) async {
    try {
      final success = await _apiService.deleteImage(imageId);
      if (success) {
        await loadGallery();
        return true;
      }
      return false;
    } catch (e) {
      print('이미지 삭제 실패: $e');
      return false;
    }
  }

  // 상태 초기화
  void resetStatus() {
    _status = GenerationStatus.idle;
    _statusMessage = null;
    notifyListeners();
  }

  // 현재 이미지 초기화
  void clearCurrentImage() {
    _currentImage = null;
    _status = GenerationStatus.idle;
    _statusMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    _wsService.dispose();
    super.dispose();
  }
}
