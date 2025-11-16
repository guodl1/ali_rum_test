/// API密钥和配置管理
/// 所有第三方服务的密钥统一在此管理
class ApiKeys {
  // 服务器配置
  static const String baseUrl = 'http://115.190.220.173:1999';
  
  // Azure TTS配置
  static const String azureTtsKey = 'YOUR_AZURE_TTS_KEY';
  static const String azureTtsRegion = 'YOUR_AZURE_REGION';
  
  // Google TTS配置
  static const String googleTtsKey = 'YOUR_GOOGLE_TTS_KEY';
  
  // PaddleOCR配置
  static const String paddleOcrKey = 'YOUR_PADDLE_OCR_KEY';
  
  // 其他配置
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> supportedImageTypes = ['.jpg', '.jpeg', '.png', '.bmp'];
  static const List<String> supportedDocTypes = ['.pdf', '.docx', '.txt', '.epub'];
  
  // 联系方式
  static const String contactEmail = '1245105585@qq.com';

  // Ali Auth (一键登录) - 填入你的 Android/ iOS SK
  static const String aliAuthAndroidSk = 'YOUR_ALI_AUTH_ANDROID_SK';
  static const String aliAuthIosSk = 'YOUR_ALI_AUTH_IOS_SK';
}
