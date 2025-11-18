import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;
import '../models/image_model.dart';

class GalleryGrid extends StatelessWidget {
  const GalleryGrid({super.key});

  void _showImageDetail(BuildContext context, ImageItem image) {
    showDialog(
      context: context,
      builder: (context) => _ImageDetailDialog(image: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<app_provider.ImageProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingGallery) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (provider.galleryImages.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('아직 생성된 이미지가 없습니다', style: ThemeConfig.bodyLarge),
                  SizedBox(height: 8),
                  Text('첫 이미지를 생성해보세요!', style: ThemeConfig.bodyMedium),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: provider.galleryImages.length,
          itemBuilder: (context, index) {
            final image = provider.galleryImages[index];
            return _GalleryItem(
              image: image,
              onTap: () => _showImageDetail(context, image),
            );
          },
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }
}

class _GalleryItem extends StatefulWidget {
  final ImageItem image;
  final VoidCallback onTap;

  const _GalleryItem({required this.image, required this.onTap});

  @override
  State<_GalleryItem> createState() => _GalleryItemState();
}

class _GalleryItemState extends State<_GalleryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isHovered
                  ? ThemeConfig.cardShadow
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 이미지
                  CachedNetworkImage(
                    imageUrl: widget.image.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.grey),
                      ),
                    ),
                  ),

                  // 그라데이션 오버레이
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.image.promptText.length > 60
                                ? '${widget.image.promptText.substring(0, 60)}...'
                                : widget.image.promptText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.image.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(widget.image.createdAt!),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('yyyy.MM.dd HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

class _ImageDetailDialog extends StatelessWidget {
  final ImageItem image;

  const _ImageDetailDialog({required this.image});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: ThemeConfig.primaryGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '이미지 상세',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 이미지
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: image.url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 프롬프트
                      const Text('프롬프트', style: ThemeConfig.headingSmall),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeConfig.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          image.promptText,
                          style: ThemeConfig.bodyMedium,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 메타 정보
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              '생성일',
                              image.createdAt != null
                                  ? DateFormat(
                                      'yyyy.MM.dd HH:mm',
                                    ).format(DateTime.parse(image.createdAt!))
                                  : '알 수 없음',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              '파일 크기',
                              '${(image.size / 1024 / 1024).toStringAsFixed(2)} MB',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ThemeConfig.caption.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(value, style: ThemeConfig.bodyMedium),
      ],
    );
  }
}
