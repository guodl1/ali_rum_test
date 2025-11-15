import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/models.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF1EEE3)
        : const Color(0xFF272536);
    final accentColor = theme.colorScheme.primary;
    
    // 根据设计，使用米黄色背景 #E8E1C4
    final cardBackgroundColor = isDark
        ? textColor.withValues(alpha: 0.06)
        : const Color(0xFFE8E1C4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.18)
              : cardBackgroundColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 左侧内容区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 语音名称
                    Row(
                      children: [
                        _buildGenderIcon(textColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            voice.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 语言标签
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            voice.language.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '已添加',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    // 描述文字
                    if (voice.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        voice.description,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 右侧播放按钮
              GestureDetector(
                onTap: onPreview,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF757575),
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: const Color(0xFF757575),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderIcon(Color textColor) {
    final gender = voice.gender.toLowerCase();
    String svgPath;
    
    if (gender == 'male') {
      svgPath = 'referPhoto/male-2.svg';
    } else if (gender == 'female') {
      svgPath = 'referPhoto/female-2.svg';
    } else {
      // 默认使用女性图标
      svgPath = 'referPhoto/female-2.svg';
    }

    return SizedBox(
      width: 20,
      height: 20,
      child: SvgPicture.asset(
        svgPath,
        colorFilter: ColorFilter.mode(
          textColor,
          BlendMode.srcIn,
        ),
        fit: BoxFit.contain,
      ),
    );
  }
}
