/// 语言检测和管理服务
class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  /// 检测文本语言
  String detectLanguage(String text) {
    if (text.isEmpty) return 'unknown';
    
    // 简单的语言检测：检查是否包含中文字符
    final chineseRegex = RegExp(r'[\u4e00-\u9fa5]');
    final hasChineseChars = chineseRegex.hasMatch(text);
    
    if (hasChineseChars) {
      // 计算中文字符比例
      final chineseCharCount = chineseRegex.allMatches(text).length;
      final totalChars = text.replaceAll(RegExp(r'\s'), '').length;
      
      if (totalChars > 0 && chineseCharCount / totalChars > 0.3) {
        return 'zh';
      }
    }
    
    // 检查是否包含英文字母
    final englishRegex = RegExp(r'[a-zA-Z]');
    if (englishRegex.hasMatch(text)) {
      return 'en';
    }
    
    return 'unknown';
  }

  /// 根据语言获取推荐的语音类型
  List<String> getRecommendedVoices(String language) {
    switch (language) {
      case 'zh':
        return ['zh-CN-XiaoxiaoNeural', 'zh-CN-YunxiNeural', 'zh-CN-YunjianNeural'];
      case 'en':
        return ['en-US-JennyNeural', 'en-US-GuyNeural', 'en-GB-SoniaNeural'];
      default:
        return [];
    }
  }

  /// 获取支持的语言列表
  List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'zh', 'name': '中文', 'name_en': 'Chinese'},
      {'code': 'en', 'name': '英文', 'name_en': 'English'},
    ];
  }
}
