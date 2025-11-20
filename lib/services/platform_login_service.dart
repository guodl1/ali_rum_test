import 'package:flutter/services.dart';
import 'dart:io';

/// 平台登录服务
/// 根据不同平台选择不同的登录方式：
/// - HarmonyOS: 使用华为账号服务一键登录
/// - iOS/Android: 使用阿里云一键登录
class PlatformLoginService {
  static const MethodChannel _channel = MethodChannel('com.example.tingyue/login');
  
  /// 检测当前是否为鸿蒙平台
  static bool get isHarmonyOS {
    try {
      // HarmonyOS 的 Platform.operatingSystem 返回 'ohos'
      return Platform.operatingSystem == 'ohos';
    } catch (e) {
      return false;
    }
  }
  
  /// 获取平台名称（用于调试）
  static String get platformName {
    if (isHarmonyOS) {
      return 'HarmonyOS';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else {
      return 'Unknown';
    }
  }
  
  /// HarmonyOS 一键登录 - 获取授权码
  /// 返回授权码，需要发送到服务器换取用户信息
  Future<String> harmonyOSQuickLogin() async {
    if (!isHarmonyOS) {
      throw UnsupportedError('HarmonyOS quick login is only supported on HarmonyOS platform');
    }
    
    try {
      final String? authCode = await _channel.invokeMethod('quickLogin');
      
      if (authCode == null || authCode.isEmpty) {
        throw Exception('Failed to get authorization code from HarmonyOS');
      }
      
      return authCode;
    } on PlatformException catch (e) {
      throw Exception('HarmonyOS quick login failed: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('HarmonyOS quick login error: $e');
    }
  }
  
  /// 检查 HarmonyOS 账号服务是否可用
  Future<bool> isHarmonyOSAccountAvailable() async {
    if (!isHarmonyOS) {
      return false;
    }
    
    try {
      final bool? available = await _channel.invokeMethod('isAccountAvailable');
      return available ?? false;
    } catch (e) {
      return false;
    }
  }
}
