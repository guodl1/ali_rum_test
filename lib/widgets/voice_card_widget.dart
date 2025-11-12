import 'package:flutter/material.dart';
import '../models/models.dart';
import 'liquid_glass_card.dart';

/// 语音类型卡片组件
/// 用于语音库展示
class VoiceCardWidget extends StatelessWidget {
  final VoiceTypeModel voice;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;
  final bool isSelected;

  const VoiceCardWidget({
    Key? key,
    required this.voice,
    this.onTap,
    this.onPreview,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onTap: onTap,
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 语音名称和性别图标
          Row(
            children: [
              Icon(
                _getGenderIcon(),
                size: 24,
                color: _getGenderColor(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  voice.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 语言标签
          Chip(
            label: Text(
              voice.language,
              style: const TextStyle(fontSize: 11),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            voice.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // 试听按钮
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Preview', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getGenderIcon() {
    switch (voice.gender.toLowerCase()) {
      case 'male':
        return Icons.face;
      case 'female':
        return Icons.face_3;
      case 'child':
        return Icons.child_care;
      default:
        return Icons.person;
    }
  }

  Color _getGenderColor() {
    switch (voice.gender.toLowerCase()) {
      case 'male':
        return Colors.blue;
      case 'female':
        return Colors.pink;
      case 'child':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
