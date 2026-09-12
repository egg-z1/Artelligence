import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;
import '../models/image_model.dart';
import 'work_detail_screen.dart';
import 'generator_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      final provider = context.read<app_provider.ImageProvider>();
      provider.checkServerHealth();
      provider.loadWorks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ThemeConfig.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _buildBookshelf(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GeneratorScreen()),
          );
        },
        backgroundColor: ThemeConfig.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('새 장면 만들기'),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📚 나의 서재',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '읽은 소설 속 장면들을 모아두는 곳',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
          _buildConnectionStatus(),
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

  Widget _buildBookshelf() {
    return Consumer<app_provider.ImageProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingWorks) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.works.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 72,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text('아직 담아둔 장면이 없어요', style: ThemeConfig.bodyLarge),
                SizedBox(height: 8),
                Text(
                  '오른쪽 아래 버튼으로 첫 장면을 만들어보세요',
                  style: ThemeConfig.bodyMedium,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.72,
          ),
          itemCount: provider.works.length,
          itemBuilder: (context, index) {
            final work = provider.works[index];
            return _BookTile(work: work);
          },
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }
}

class _BookTile extends StatefulWidget {
  final Work work;

  const _BookTile({required this.work});

  @override
  State<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<_BookTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkDetailScreen(
                workTitle: widget.work.workTitle == '미분류'
                    ? null
                    : widget.work.workTitle,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.04 : 1.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isHovered ? ThemeConfig.cardShadow : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.work.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.book, color: Colors.grey),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.work.sceneCount}장면',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.work.workTitle,
                style: ThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
