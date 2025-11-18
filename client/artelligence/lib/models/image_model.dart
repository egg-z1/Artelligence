import 'package:json_annotation/json_annotation.dart';

part 'image_model.g.dart';

@JsonSerializable()
class GeneratedImage {
  @JsonKey(name: 'image_id')
  final String imageId;

  @JsonKey(name: 'image_url')
  final String imageUrl;

  @JsonKey(name: 'blob_url')
  final String? blobUrl;

  final String prompt;

  @JsonKey(name: 'created_at')
  final String createdAt;

  final String status;

  GeneratedImage({
    required this.imageId,
    required this.imageUrl,
    this.blobUrl,
    required this.prompt,
    required this.createdAt,
    required this.status,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) =>
      _$GeneratedImageFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratedImageToJson(this);
}

@JsonSerializable()
class ImageListResponse {
  final List<ImageItem> images;
  final int total;

  ImageListResponse({required this.images, required this.total});

  factory ImageListResponse.fromJson(Map<String, dynamic> json) =>
      _$ImageListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ImageListResponseToJson(this);
}

@JsonSerializable()
class ImageItem {
  @JsonKey(name: 'image_id')
  final String imageId;

  @JsonKey(name: 'blob_name')
  final String blobName;

  final String url;
  final int size;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  final Map<String, dynamic>? metadata;

  ImageItem({
    required this.imageId,
    required this.blobName,
    required this.url,
    required this.size,
    this.createdAt,
    this.metadata,
  });

  factory ImageItem.fromJson(Map<String, dynamic> json) =>
      _$ImageItemFromJson(json);

  Map<String, dynamic> toJson() => _$ImageItemToJson(this);

  String get promptText => metadata?['prompt'] ?? '프롬프트 없음';
}

@JsonSerializable()
class GenerationRequest {
  final String prompt;
  final String size;
  final String quality;
  final String style;

  GenerationRequest({
    required this.prompt,
    this.size = '1024x1024',
    this.quality = 'standard',
    this.style = 'vivid',
  });

  factory GenerationRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GenerationRequestToJson(this);
}

@JsonSerializable()
class HealthStatus {
  final String status;
  final String timestamp;
  final String service;

  HealthStatus({
    required this.status,
    required this.timestamp,
    required this.service,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) =>
      _$HealthStatusFromJson(json);

  Map<String, dynamic> toJson() => _$HealthStatusToJson(this);

  bool get isHealthy => status == 'healthy';
}

// WebSocket 메시지
class WebSocketMessage {
  final String status;
  final String? message;
  final String? imageId;
  final String? imageUrl;
  final String? blobUrl;

  WebSocketMessage({
    required this.status,
    this.message,
    this.imageId,
    this.imageUrl,
    this.blobUrl,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      status: json['status'] as String,
      message: json['message'] as String?,
      imageId: json['image_id'] as String?,
      imageUrl: json['image_url'] as String?,
      blobUrl: json['blob_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        if (message != null) 'message': message,
        if (imageId != null) 'image_id': imageId,
        if (imageUrl != null) 'image_url': imageUrl,
        if (blobUrl != null) 'blob_url': blobUrl,
      };
}
