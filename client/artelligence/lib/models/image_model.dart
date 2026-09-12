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

  @JsonKey(name: 'work_title')
  final String? workTitle;

  final String? excerpt;

  @JsonKey(name: 'created_at')
  final String createdAt;

  final String status;

  GeneratedImage({
    required this.imageId,
    required this.imageUrl,
    this.blobUrl,
    required this.prompt,
    this.workTitle,
    this.excerpt,
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

  final String? prompt;

  @JsonKey(name: 'work_title')
  final String? workTitle;

  final String? excerpt;

  ImageItem({
    required this.imageId,
    required this.blobName,
    required this.url,
    required this.size,
    this.createdAt,
    this.prompt,
    this.workTitle,
    this.excerpt,
  });

  factory ImageItem.fromJson(Map<String, dynamic> json) =>
      _$ImageItemFromJson(json);

  Map<String, dynamic> toJson() => _$ImageItemToJson(this);

  String get promptText => prompt ?? '프롬프트 없음';
}

@JsonSerializable(includeIfNull: false)
class GenerationRequest {
  final String prompt;
  final String size;
  final String quality;
  final String style;

  @JsonKey(name: 'work_title')
  final String? workTitle;

  final String? excerpt;

  GenerationRequest({
    required this.prompt,
    this.size = '1024x1024',
    this.quality = 'standard',
    this.style = 'vivid',
    this.workTitle,
    this.excerpt,
  });

  factory GenerationRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GenerationRequestToJson(this);
}

@JsonSerializable()
class Work {
  @JsonKey(name: 'work_title')
  final String workTitle;

  @JsonKey(name: 'scene_count')
  final int sceneCount;

  @JsonKey(name: 'thumbnail_url')
  final String thumbnailUrl;

  @JsonKey(name: 'latest_created_at')
  final String? latestCreatedAt;

  Work({
    required this.workTitle,
    required this.sceneCount,
    required this.thumbnailUrl,
    this.latestCreatedAt,
  });

  factory Work.fromJson(Map<String, dynamic> json) => _$WorkFromJson(json);

  Map<String, dynamic> toJson() => _$WorkToJson(this);
}

@JsonSerializable()
class WorkListResponse {
  final List<Work> works;

  WorkListResponse({required this.works});

  factory WorkListResponse.fromJson(Map<String, dynamic> json) =>
      _$WorkListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WorkListResponseToJson(this);
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
  final String? workTitle;
  final String? excerpt;

  WebSocketMessage({
    required this.status,
    this.message,
    this.imageId,
    this.imageUrl,
    this.blobUrl,
    this.workTitle,
    this.excerpt,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      status: json['status'] as String,
      message: json['message'] as String?,
      imageId: json['image_id'] as String?,
      imageUrl: json['image_url'] as String?,
      blobUrl: json['blob_url'] as String?,
      workTitle: json['work_title'] as String?,
      excerpt: json['excerpt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        if (message != null) 'message': message,
        if (imageId != null) 'image_id': imageId,
        if (imageUrl != null) 'image_url': imageUrl,
        if (blobUrl != null) 'blob_url': blobUrl,
        if (workTitle != null) 'work_title': workTitle,
        if (excerpt != null) 'excerpt': excerpt,
      };
}
