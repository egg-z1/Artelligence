import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;
import '../widgets/image_generator_form.dart';
import '../widgets/image_preview.dart';
import '../widgets/gallery_grid.dart';
import '../widgets/status_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 주기적으로 서버 상태 확인
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      final provider = context.read<app_provider.ImageProvider>();
      provider.checkServerHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: ThemeConfig.backgroundColor),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildMainContent(),
                      const SizedBox(height: 40),
                      _buildGallerySection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎨 Artelligence',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '머릿속 상상을 현실로 만들어보세요',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
              _buildConnectionStatus(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<app_provider.ImageProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ThemeConfig.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: provider.isServerHealthy
                    ? ThemeConfig.successColor
                    : ThemeConfig.errorColor,
              ),
              const SizedBox(width: 8),
              Text(
                provider.isServerHealthy ? '서버 연결됨' : '서버 연결 안됨',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: provider.isServerHealthy
                      ? ThemeConfig.successColor
                      : ThemeConfig.errorColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1024) {
          // 데스크톱 레이아웃
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildGeneratorCard()),
              const SizedBox(width: 30),
              Expanded(child: _buildPreviewCard()),
            ],
          );
        } else {
          // 모바일 레이아웃
          return Column(
            children: [
              _buildGeneratorCard(),
              const SizedBox(height: 20),
              _buildPreviewCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildGeneratorCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✨ 이미지 생성', style: ThemeConfig.headingMedium),
            const SizedBox(height: 20),
            const ImageGeneratorForm(),
            const SizedBox(height: 20),
            const StatusIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🖼️ 결과', style: ThemeConfig.headingMedium),
            const SizedBox(height: 20),
            const ImagePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📚 최근 생성된 이미지', style: ThemeConfig.headingMedium),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<app_provider.ImageProvider>().loadGallery();
                  },
                  tooltip: '새로고침',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const GalleryGrid(),
          ],
        ),
      ),
    );
  }
}
