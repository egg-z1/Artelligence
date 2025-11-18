import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/image_model.dart';

class ApiService {
  final http.Client _client = http.Client();

  // 헬스체크
  Future<HealthStatus> checkHealth() async {
    try {
      final response = await _client
          .get(
            Uri.parse(ApiConfig.getFullUrl(ApiConfig.healthEndpoint)),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return HealthStatus.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버에 연결할 수 없습니다: $e');
    }
  }

  // 이미지 생성
  Future<GeneratedImage> generateImage(GenerationRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse(ApiConfig.getFullUrl(ApiConfig.generateEndpoint)),
            headers: ApiConfig.headers,
            body: jsonEncode(request.toJson()),
          )
          .timeout(ApiConfig.generateTimeout);

      if (response.statusCode == 200) {
        return GeneratedImage.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '이미지 생성 실패');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('이미지 생성 시간 초과 (3분 초과)');
      }
      rethrow;
    }
  }

  // 이미지 목록 조회
  Future<ImageListResponse> getImages({int limit = 12, int offset = 0}) async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiConfig.imagesEndpoint))
          .replace(
            queryParameters: {
              'limit': limit.toString(),
              'offset': offset.toString(),
            },
          );

      final response = await _client
          .get(uri, headers: ApiConfig.headers)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return ImageListResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('이미지 목록 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('이미지 목록을 불러올 수 없습니다: $e');
    }
  }

  // 특정 이미지 조회
  Future<ImageItem> getImage(String imageId) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              ApiConfig.getFullUrl('${ApiConfig.imagesEndpoint}/$imageId'),
            ),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return ImageItem.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('이미지를 찾을 수 없습니다');
      } else {
        throw Exception('이미지 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 이미지 삭제
  Future<bool> deleteImage(String imageId) async {
    try {
      final response = await _client
          .delete(
            Uri.parse(
              ApiConfig.getFullUrl('${ApiConfig.imagesEndpoint}/$imageId'),
            ),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('이미지 삭제 실패: $e');
    }
  }

  // 메트릭스 조회
  Future<Map<String, dynamic>> getMetrics() async {
    try {
      final response = await _client
          .get(
            Uri.parse(ApiConfig.getFullUrl(ApiConfig.metricsEndpoint)),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('메트릭스 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('메트릭스를 불러올 수 없습니다: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
