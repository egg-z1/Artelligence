// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneratedImage _$GeneratedImageFromJson(Map<String, dynamic> json) =>
    GeneratedImage(
      imageId: json['image_id'] as String,
      imageUrl: json['image_url'] as String,
      blobUrl: json['blob_url'] as String?,
      prompt: json['prompt'] as String,
      workTitle: json['work_title'] as String?,
      excerpt: json['excerpt'] as String?,
      createdAt: json['created_at'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$GeneratedImageToJson(GeneratedImage instance) =>
    <String, dynamic>{
      'image_id': instance.imageId,
      'image_url': instance.imageUrl,
      'blob_url': instance.blobUrl,
      'prompt': instance.prompt,
      'work_title': instance.workTitle,
      'excerpt': instance.excerpt,
      'created_at': instance.createdAt,
      'status': instance.status,
    };

ImageListResponse _$ImageListResponseFromJson(Map<String, dynamic> json) =>
    ImageListResponse(
      images: (json['images'] as List<dynamic>)
          .map((e) => ImageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$ImageListResponseToJson(ImageListResponse instance) =>
    <String, dynamic>{'images': instance.images, 'total': instance.total};

ImageItem _$ImageItemFromJson(Map<String, dynamic> json) => ImageItem(
  imageId: json['image_id'] as String,
  blobName: json['blob_name'] as String,
  url: json['url'] as String,
  size: (json['size'] as num).toInt(),
  createdAt: json['created_at'] as String?,
  prompt: json['prompt'] as String?,
  workTitle: json['work_title'] as String?,
  excerpt: json['excerpt'] as String?,
);

Map<String, dynamic> _$ImageItemToJson(ImageItem instance) => <String, dynamic>{
  'image_id': instance.imageId,
  'blob_name': instance.blobName,
  'url': instance.url,
  'size': instance.size,
  'created_at': instance.createdAt,
  'prompt': instance.prompt,
  'work_title': instance.workTitle,
  'excerpt': instance.excerpt,
};

GenerationRequest _$GenerationRequestFromJson(Map<String, dynamic> json) =>
    GenerationRequest(
      prompt: json['prompt'] as String,
      size: json['size'] as String? ?? '1024x1024',
      quality: json['quality'] as String? ?? 'standard',
      style: json['style'] as String? ?? 'vivid',
      workTitle: json['work_title'] as String?,
      excerpt: json['excerpt'] as String?,
    );

Map<String, dynamic> _$GenerationRequestToJson(GenerationRequest instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
      'size': instance.size,
      'quality': instance.quality,
      'style': instance.style,
      'work_title': ?instance.workTitle,
      'excerpt': ?instance.excerpt,
    };

Work _$WorkFromJson(Map<String, dynamic> json) => Work(
  workTitle: json['work_title'] as String,
  sceneCount: (json['scene_count'] as num).toInt(),
  thumbnailUrl: json['thumbnail_url'] as String,
  latestCreatedAt: json['latest_created_at'] as String?,
);

Map<String, dynamic> _$WorkToJson(Work instance) => <String, dynamic>{
  'work_title': instance.workTitle,
  'scene_count': instance.sceneCount,
  'thumbnail_url': instance.thumbnailUrl,
  'latest_created_at': instance.latestCreatedAt,
};

WorkListResponse _$WorkListResponseFromJson(Map<String, dynamic> json) =>
    WorkListResponse(
      works: (json['works'] as List<dynamic>)
          .map((e) => Work.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$WorkListResponseToJson(WorkListResponse instance) =>
    <String, dynamic>{'works': instance.works};

HealthStatus _$HealthStatusFromJson(Map<String, dynamic> json) => HealthStatus(
  status: json['status'] as String,
  timestamp: json['timestamp'] as String,
  service: json['service'] as String,
);

Map<String, dynamic> _$HealthStatusToJson(HealthStatus instance) =>
    <String, dynamic>{
      'status': instance.status,
      'timestamp': instance.timestamp,
      'service': instance.service,
    };
