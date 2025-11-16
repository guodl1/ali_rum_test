import 'dart:convert';

/// Titles 模型
/// 用于解析 Minimax 返回的 titles 文件
class TitleSegment {
  final String text;
  final String pronounceText;
  final double timeBegin; // 开始时间（毫秒）
  final double timeEnd; // 结束时间（毫秒）
  final int textBegin; // 文本开始位置
  final int textEnd; // 文本结束位置
  final int pronounceTextBegin;
  final int pronounceTextEnd;
  final List<dynamic>? timestampedWords;

  TitleSegment({
    required this.text,
    required this.pronounceText,
    required this.timeBegin,
    required this.timeEnd,
    required this.textBegin,
    required this.textEnd,
    required this.pronounceTextBegin,
    required this.pronounceTextEnd,
    this.timestampedWords,
  });

  factory TitleSegment.fromJson(Map<String, dynamic> json) {
    return TitleSegment(
      text: json['text'] ?? '',
      pronounceText: json['pronounce_text'] ?? '',
      timeBegin: (json['time_begin'] ?? 0).toDouble(),
      timeEnd: (json['time_end'] ?? 0).toDouble(),
      textBegin: json['text_begin'] ?? 0,
      textEnd: json['text_end'] ?? 0,
      pronounceTextBegin: json['pronounce_text_begin'] ?? 0,
      pronounceTextEnd: json['pronounce_text_end'] ?? 0,
      timestampedWords: json['timestamped_words'],
    );
  }

  /// 判断给定的播放时间（毫秒）是否在此段落内
  bool containsTime(double currentTimeMs) {
    return currentTimeMs >= timeBegin && currentTimeMs <= timeEnd;
  }
}

/// Titles 解析服务
class TitlesParser {
  /// 从 JSON 字符串解析 titles
  static List<TitleSegment> parseTitles(String jsonString) {
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => TitleSegment.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error parsing titles: $e');
      return [];
    }
  }

  /// 根据当前播放时间获取对应的段落索引
  static int? getCurrentSegmentIndex(List<TitleSegment> segments, double currentTimeMs) {
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].containsTime(currentTimeMs)) {
        return i;
      }
    }
    return null;
  }

  /// 获取完整文本（用于显示）
  static String getFullText(List<TitleSegment> segments) {
    if (segments.isEmpty) return '';
    
    // 根据 text_begin 排序
    final sorted = List<TitleSegment>.from(segments);
    sorted.sort((a, b) => a.textBegin.compareTo(b.textBegin));
    
    // 拼接所有文本
    return sorted.map((s) => s.text).join('');
  }
}

