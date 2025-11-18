import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/image_model.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<WebSocketMessage>? _messageController;
  String? _clientId;
  bool _isConnected = false;

  Stream<WebSocketMessage>? get messageStream => _messageController?.stream;
  bool get isConnected => _isConnected;

  // 연결
  Future<void> connect(String clientId) async {
    if (_isConnected) {
      return;
    }

    try {
      _clientId = clientId;
      final wsUrl = ApiConfig.getWsUrl(ApiConfig.wsEndpoint(clientId));

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _messageController = StreamController<WebSocketMessage>.broadcast();

      _channel!.stream.listen(
        (data) {
          try {
            final message = WebSocketMessage.fromJson(jsonDecode(data));
            _messageController!.add(message);
          } catch (e) {
            print('WebSocket 메시지 파싱 오류: $e');
          }
        },
        onError: (error) {
          print('WebSocket 오류: $error');
          _isConnected = false;
          _attemptReconnect();
        },
        onDone: () {
          print('WebSocket 연결 종료');
          _isConnected = false;
          _attemptReconnect();
        },
      );

      _isConnected = true;
      print('WebSocket 연결 성공: $wsUrl');
    } catch (e) {
      print('WebSocket 연결 실패: $e');
      _isConnected = false;
      throw Exception('WebSocket 연결 실패: $e');
    }
  }

  // 재연결 시도
  void _attemptReconnect() {
    if (_clientId != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected) {
          print('WebSocket 재연결 시도...');
          connect(_clientId!);
        }
      });
    }
  }

  // 메시지 전송
  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      throw Exception('WebSocket이 연결되지 않았습니다');
    }

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      print('메시지 전송 오류: $e');
      throw Exception('메시지 전송 실패: $e');
    }
  }

  // 이미지 생성 요청 (WebSocket)
  void requestImageGeneration({
    required String prompt,
    String size = '1024x1024',
    String quality = 'standard',
    String style = 'vivid',
  }) {
    sendMessage({
      'action': 'generate',
      'prompt': prompt,
      'size': size,
      'quality': quality,
      'style': style,
    });
  }

  // 연결 종료
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      await _messageController?.close();
      _isConnected = false;
      print('WebSocket 연결 종료');
    } catch (e) {
      print('WebSocket 종료 오류: $e');
    }
  }

  void dispose() {
    disconnect();
  }
}
