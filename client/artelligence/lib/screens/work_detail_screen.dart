import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;
import '../widgets/gallery_grid.dart';
import 'generator_screen.dart';

class WorkDetailScreen extends StatefulWidget {
  final String? workTitle; // null이면 '미분류'

  const WorkDetailScreen({super.key, this.workTitle});

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      context.read<app_provider.ImageProvider>().selectWork(widget.workTitle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor,
      appBar: AppBar(
        title: Text(widget.workTitle ?? '미분류 장면'),
        backgroundColor: Colors.white,
        foregroundColor: ThemeConfig.textPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<app_provider.ImageProvider>().loadGallery(
                workTitle: widget.workTitle,
              );
            },
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: GalleryGrid(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  GeneratorScreen(initialWorkTitle: widget.workTitle),
            ),
          );
        },
        backgroundColor: ThemeConfig.primaryColor,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('장면 추가'),
      ),
    );
  }
}
