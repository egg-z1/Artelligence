import 'package:flutter/material.dart';
import '../config/theme_config.dart';
import '../widgets/image_generator_form.dart';
import '../widgets/image_preview.dart';
import '../widgets/status_indicator.dart';

class GeneratorScreen extends StatelessWidget {
  final String? initialWorkTitle;

  const GeneratorScreen({super.key, this.initialWorkTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.backgroundColor,
      appBar: AppBar(
        title: Text(
          initialWorkTitle != null ? '$initialWorkTitle · 새 장면' : '새 장면 만들기',
        ),
        backgroundColor: Colors.white,
        foregroundColor: ThemeConfig.textPrimaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = _buildGeneratorCard();
            final preview = _buildPreviewCard();

            if (constraints.maxWidth > 1024) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  const SizedBox(width: 30),
                  Expanded(child: preview),
                ],
              );
            }
            return Column(
              children: [form, const SizedBox(height: 20), preview],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGeneratorCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✨ 장면 만들기', style: ThemeConfig.headingMedium),
            const SizedBox(height: 20),
            ImageGeneratorForm(initialWorkTitle: initialWorkTitle),
            const SizedBox(height: 20),
            const StatusIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(30),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🖼️ 결과', style: ThemeConfig.headingMedium),
            SizedBox(height: 20),
            ImagePreview(),
          ],
        ),
      ),
    );
  }
}
