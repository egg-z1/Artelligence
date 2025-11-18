import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;

class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key});

  Future<void> _downloadImage(BuildContext context, String imageUrl) async {
    try {
      // 로딩 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지 다운로드 중...')));

      // 이미지 다운로드
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        // 파일 저장
        final fileName =
            'artelligence_${DateTime.now().millisecondsSinceEpoch}.png';
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: response.bodyBytes,
          ext: 'png',
          mimeType: MimeType.png,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 이미지가 다운로드되었습니다'),
              backgroundColor: ThemeConfig.successColor,
            ),
          );
        }
      } else {
        throw Exception('이미지 다운로드 실패');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 다운로드 실패: ${e.toString()}'),
            backgroundColor: ThemeConfig.errorColor,
          ),
        );
      }
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<app_provider.ImageProvider>(
      builder: (context, provider, child) {
        if (provider.isGenerating) {
          return _buildLoadingState();
        }

        if (provider.currentImage != null) {
          return _buildImageResult(context, provider);
        }

        return _buildPlaceholder();
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: ThemeConfig.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeConfig.primaryColor,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text('이미지 생성 중...', style: ThemeConfig.bodyLarge),
          SizedBox(height: 8),
          Text('최대 3분 소요될 수 있습니다', style: ThemeConfig.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildImageResult(
    BuildContext context,
    app_provider.ImageProvider provider,
  ) {
    final image = provider.currentImage!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 이미지
        GestureDetector(
          onTap: () => _showFullImage(context, image.imageUrl),
          child: Container(
            constraints: const BoxConstraints(minHeight: 300, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: ThemeConfig.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: image.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('이미지를 불러올 수 없습니다'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 프롬프트 표시
        if (image.prompt.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeConfig.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              image.prompt,
              style: ThemeConfig.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        const SizedBox(height: 16),

        // 액션 버튼들
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _downloadImage(context, image.imageUrl),
                icon: const Icon(Icons.download),
                label: const Text('다운로드'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.successColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showFullImage(context, image.imageUrl),
                icon: const Icon(Icons.fullscreen),
                label: const Text('확대보기'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: ThemeConfig.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '왼쪽에서 장면을 묘사하고',
            style: ThemeConfig.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '이미지를 생성해보세요',
            style: ThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
