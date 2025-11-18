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
      createdAt: json['created_at'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$GeneratedImageToJson(GeneratedImage instance) =>
    <String, dynamic>{
      'image_id': instance.imageId,
      'image_url': instance.imageUrl,
      'blob_url': instance.blobUrl,
      'prompt': instance.prompt,
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
    <String, dynamic>{
      'images': instance.images,
      'total': instance.total,
    };

ImageItem _$ImageItemFromJson(Map<String, dynamic> json) => ImageItem(
      imageId: json['image_id'] as String,
      blobName: json['blob_name'] as String,
      url: json['url'] as String,
      size: (json['size'] as num).toInt(),
      createdAt: json['created_at'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ImageItemToJson(ImageItem instance) => <String, dynamic>{
      'image_id': instance.imageId,
      'blob_name': instance.blobName,
      'url': instance.url,
      'size': instance.size,
      'created_at': instance.createdAt,
      'metadata': instance.metadata,
    };

GenerationRequest _$GenerationRequestFromJson(Map<String, dynamic> json) =>
    GenerationRequest(
      prompt: json['prompt'] as String,
      size: json['size'] as String? ?? '1024x1024',
      quality: json['quality'] as String? ?? 'standard',
      style: json['style'] as String? ?? 'vivid',
    );

Map<String, dynamic> _$GenerationRequestToJson(GenerationRequest instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
      'size': instance.size,
      'quality': instance.quality,
      'style': instance.style,
    };

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
