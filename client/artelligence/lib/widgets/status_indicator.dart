import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<app_provider.ImageProvider>(
      builder: (context, provider, child) {
        if (provider.status == app_provider.GenerationStatus.idle) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getBackgroundColor(provider.status),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _getBackgroundColor(provider.status).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildIcon(provider.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(provider.status),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (provider.statusMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        provider.statusMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (provider.status != app_provider.GenerationStatus.error)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => provider.resetStatus(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(app_provider.GenerationStatus status) {
    switch (status) {
      case app_provider.GenerationStatus.processing:
      case app_provider.GenerationStatus.saving:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case app_provider.GenerationStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.white, size: 24);
      case app_provider.GenerationStatus.error:
        return const Icon(Icons.error, color: Colors.white, size: 24);
      default:
        return const SizedBox.shrink();
    }
  }

  String _getTitle(app_provider.GenerationStatus status) {
    switch (status) {
      case app_provider.GenerationStatus.processing:
        return '이미지 생성 중';
      case app_provider.GenerationStatus.saving:
        return '이미지 저장 중';
      case app_provider.GenerationStatus.completed:
        return '완료!';
      case app_provider.GenerationStatus.error:
        return '오류 발생';
      default:
        return '';
    }
  }

  Color _getBackgroundColor(app_provider.GenerationStatus status) {
    switch (status) {
      case app_provider.GenerationStatus.processing:
      case app_provider.GenerationStatus.saving:
        return ThemeConfig.warningColor;
      case app_provider.GenerationStatus.completed:
        return ThemeConfig.successColor;
      case app_provider.GenerationStatus.error:
        return ThemeConfig.errorColor;
      default:
        return Colors.grey;
    }
  }
}
