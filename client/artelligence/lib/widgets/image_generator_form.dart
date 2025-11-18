import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/image_provider.dart' as app_provider;

class ImageGeneratorForm extends StatefulWidget {
  const ImageGeneratorForm({super.key});

  @override
  State<ImageGeneratorForm> createState() => _ImageGeneratorFormState();
}

class _ImageGeneratorFormState extends State<ImageGeneratorForm> {
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();

  String _selectedSize = '1024x1024';
  String _selectedQuality = 'standard';
  String _selectedStyle = 'vivid';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<app_provider.ImageProvider>();

      provider.generateImage(
        prompt: _promptController.text.trim(),
        size: _selectedSize,
        quality: _selectedQuality,
        style: _selectedStyle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 프롬프트 입력
          TextFormField(
            controller: _promptController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '장면 묘사 *',
              hintText: '예: 고요한 호수 위에 떠 있는 작은 배, 석양의 황금빛이 물결에 반짝인다...',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '장면 묘사를 입력해주세요';
              }
              if (value.trim().length < 10) {
                return '최소 10자 이상 입력해주세요';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // 옵션들
          Row(
            children: [
              Expanded(child: _buildSizeDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _buildQualityDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _buildStyleDropdown()),
            ],
          ),

          const SizedBox(height: 30),

          // 생성 버튼
          Consumer<app_provider.ImageProvider>(
            builder: (context, provider, child) {
              return ElevatedButton(
                onPressed: provider.isGenerating ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ThemeConfig.primaryColor,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: provider.isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('생성 중...'),
                        ],
                      )
                    : const Text(
                        '🎨 이미지 생성하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSizeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSize,
      decoration: const InputDecoration(
        labelText: '이미지 크기',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: '1024x1024', child: Text('정사각형')),
        DropdownMenuItem(value: '1792x1024', child: Text('가로형')),
        DropdownMenuItem(value: '1024x1792', child: Text('세로형')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedSize = value);
        }
      },
    );
  }

  Widget _buildQualityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedQuality,
      decoration: const InputDecoration(
        labelText: '품질',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: 'standard', child: Text('일반')),
        DropdownMenuItem(value: 'hd', child: Text('HD')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedQuality = value);
        }
      },
    );
  }

  Widget _buildStyleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedStyle,
      decoration: const InputDecoration(
        labelText: '스타일',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(value: 'vivid', child: Text('생동감')),
        DropdownMenuItem(value: 'natural', child: Text('자연스럽게')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedStyle = value);
        }
      },
    );
  }
}
