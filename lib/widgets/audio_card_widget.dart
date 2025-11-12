import 'package:flutter/material.dart';
import '../models/models.dart';
import 'liquid_glass_card.dart';

/// 音频卡片组件
/// 展示历史记录中的音频项
class AudioCardWidget extends StatelessWidget {
  final HistoryModel history;
  final VoidCallback? onPlay;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;

  const AudioCardWidget({
    Key? key,
    required this.history,
    this.onPlay,
    this.onFavorite,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                _getFileIcon(history.file?.type ?? 'unknown'),
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  history.file?.originalName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  history.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: history.isFavorite ? Colors.red : null,
                ),
                onPressed: onFavorite,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 语音类型和时间
          Row(
            children: [
              Chip(
                label: Text(
                  history.voiceType,
                  style: const TextStyle(fontSize: 12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(history.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                color: Colors.red[400],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'epub':
        return Icons.menu_book;
      case 'url':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
