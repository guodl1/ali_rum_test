/// API密钥和配置管理
/// 所有第三方服务的密钥统一在此管理
class ApiKeys {
  // 服务器配置
  static const String baseUrl = 'https://tingyue.top:1999';
  
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
  static const String aliAuthAndroidSk = 'lEhoFoaBFzq8pcm+y73JYe6VKPV1ulR02CsHgKcRfVKOxaAsoSEjcKp6QUeHUlMD6t2pRDpnXeR81vAT9ivIioOlj7TvbfSojze5P2YLd9FmlToVTkA+Bxl/U3EIXDJCN2If98gBBhHOb/qUxGcNszAGqtM6AV5axcul+jDlO+8wUbou5RCKIOqfwPrjQIIjrqoQChMeCBQdV7Tu526alV6SJFH+wk7NP7DjnxUjca6xJU9IgWC1GxEzboprldvWjAwHrAC/bXXfzSm3Gmq7TjrtE3/WkC+N6JF2xSmCahLu/IUW60ELEQ==';
  static const String aliAuthIosSk = '1QE/527HJl//eWVt4REbBB5z3FvOM9hBhIAH6wN4uhQETGe7WYtHpS0VqtThaAUGmpw31DA/9qvsPedvVDab6GeOK/kmS1OYGv8EpoNg/Nb2rjOuMKMv2rZ0BFkMJD17MPMLBjvzbMDKbaRNGS5zDQkprMEZToMZBxwAfzUvietu4svHYu4tGReEGfcl02K0SdXjqnv69ohkZUdyhJKFQb6aZYs2msCD1RxDU1fuSjmubLF46IlSL6jdMOLf8PU4g0Xta7phZfk=';

  // Alipay Configuration
  // Note: Sensitive keys should be kept on the server.
  // These are for client-side configuration if needed (e.g. scheme).
  static const String alipayScheme = 'alipay_scheme'; // Replace with your scheme
}
