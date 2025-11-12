/// 应用配置
class AppConfig {
  // 应用信息
  static const String appName = 'TTS Reader';
  static const String appVersion = '1.0.0';
  
  // 超时配置
  static const int connectionTimeout = 30000; // 30秒
  static const int receiveTimeout = 60000; // 60秒
  
  // 缓存配置
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const int cacheExpireDays = 7;
  
  // 分页配置
  static const int pageSize = 20;
  
  // 动画配置
  static const int animationDuration = 300; // 毫秒
}
