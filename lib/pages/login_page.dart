import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ali_auth/ali_auth.dart';
import '../config/api_keys.dart';

// localization handled elsewhere
import '../services/api_service.dart';
import '../services/platform_login_service.dart';

/// 登录页面
/// 使用阿里云一键登录服务
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final PlatformLoginService _platformLoginService = PlatformLoginService();
  bool _isInitialized = false;
  String? _errorMessage;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    if (PlatformLoginService.isHarmonyOS) {
      // HarmonyOS 不需要初始化 Ali Auth
      _updateState(() {
        _isInitialized = true;
      });
    } else {
      _initializeAuth();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!PlatformLoginService.isHarmonyOS) {
      _disposeSdkIfNeeded();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // SDK 会自动管理页面生命周期，无需手动处理
  }

  

  /// 初始化阿里云一键登录SDK（参考文档要求：先监听再初始化）
  Future<void> _initializeAuth() async {
    try {
      // 先注册监听，确保在任何 login 之前
      AliAuth.loginListen(onEvent: (event) {
        _handleLoginEvent(event);
      });

      await AliAuth.initSdk(_buildFullScreenConfig());

      _updateState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('初始化阿里云一键登录失败: $e');
      }
      _updateState(() {
        _errorMessage = '初始化失败: $e';
        _isInitialized = false;
      });
    }
  }

  /// 一键登录
  Future<void> _oneClickLogin() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SDK未初始化，请稍后重试')),
      );
      return;
    }

    if (PlatformLoginService.isHarmonyOS) {
      await _harmonyOSLogin();
    } else {
      await _aliAuthLogin();
    }
  }

  /// 阿里云一键登录（SDK 自动管理 loading 和页面退出）
  Future<void> _aliAuthLogin() async {
    try {
      // SDK 会自动显示 loading，登录成功后自动退出页面（autoQuitPage: true）
      await AliAuth.login();
    } catch (e) {
      if (kDebugMode) {
        print('一键登录错误: $e');
      }
      _updateState(() {
        _errorMessage = '登录失败: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 鸿蒙一键登录
  Future<void> _harmonyOSLogin() async {
    try {
      // 显示 loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. 调用原生获取授权码
      final authCode = await _platformLoginService.harmonyOSQuickLogin();
      
      if (kDebugMode) {
        print('HarmonyOS Auth Code: $authCode');
      }

      // 2. 发送到服务器换取用户信息
      final response = await _apiService.loginWithHuaweiCode(authCode);
      
      // 关闭 loading
      if (mounted) {
        Navigator.pop(context);
      }

      // 3. 保存用户信息并跳转
      if (response['success'] == true) {
        final data = response['data'];
        // 这里可以根据需要处理返回的数据，比如保存 token 等
        // 目前逻辑是直接跳转到主页，假设服务器已经处理了 session
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
          );
          // 延迟跳转，让用户看到成功提示
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        throw Exception(response['message'] ?? '登录失败');
      }
    } catch (e) {
      // 关闭 loading
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (kDebugMode) {
        print('鸿蒙登录失败: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLoginEvent(dynamic rawEvent) async {
    final event = _normalizeEvent(rawEvent);
    final code = event['code']?.toString() ?? '';
    final message = event['msg']?.toString() ?? '';
    final eventData = event['data'];

    if (kDebugMode) {
      print('AliAuth Event -> $event');
    }

    void showToast(Color color) {
      if (!mounted || message.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    switch (code) {
      case '700000': // 点击返回
      case '700001': // 切换账号
        // 用户取消登录，SDK 会自动退出页面（autoQuitPage: true）
        showToast(Colors.red);
        _setStatus(message.isEmpty ? '用户取消' : message);
        _updateState(() {
          _errorMessage = message.isEmpty ? '用户取消' : message;
        });
        break;

      case '700002': // 点击登录按钮
      case '700003': // 勾选 CheckBox
      case '700004': // 点击协议
      case '700005': // 点击第三方按钮
        showToast(Colors.blueGrey);
        _setStatus('事件($code): $message');
        break;

      case '600000': // 登录成功
        // SDK 会自动退出页面（autoQuitPage: true），无需手动调用 quitPage
        final parsed = _parseLoginData(eventData);
        final token = parsed['token'] ?? '';

        String? serverPhone;
        int? serverUserId;
        try {
          final serverResult = await _exchangeTokenWithServer(token);
          serverPhone = serverResult?.phone;
          serverUserId = serverResult?.userId;
        } catch (e) {
          if (kDebugMode) {
            print('Server token exchange failed: $e');
          }
        }

        final phoneToPrint = serverPhone;
        if (kDebugMode) {
          print('AliAuth 登录手机号: ${phoneToPrint ?? '未知'}');
        }

        _setStatus('登录成功');
        _updateState(() {
          _errorMessage = null; // 清除错误信息
        });

        final result = {
          'token': token,
          if (phoneToPrint != null) 'phone': phoneToPrint,
          if (serverUserId != null) 'user_id': serverUserId,
        };

        // 等待 SDK 自动退出页面后再返回结果
        // 使用 Future.delayed 确保页面已退出
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.of(context).pop(result);
          }
        });
        break;

      default:
        showToast(Colors.orange);
        _setStatus('未知事件($code): $message');
        break;
    }
  }

  Map<String, dynamic> _normalizeEvent(dynamic rawEvent) {
    if (rawEvent is Map) {
      return rawEvent.map((key, value) => MapEntry(
            key.toString(),
            value,
          ));
    }
    if (rawEvent == null) return {};
    return {'code': rawEvent.toString(), 'msg': rawEvent.toString()};
  }

  Map<String, String?> _parseLoginData(dynamic data) {
    if (data is Map) {
      final token = data['token']?.toString() ?? '';
      final phone = data['phone']?.toString();
      if (kDebugMode) {
        print('AliAuth 登录手机号(客户端返回): ${phone ?? '未知'}');
      }
      return {'token': token, 'phone': phone};
    }
    final token = data?.toString() ?? '';
    return {'token': token, 'phone': null};
  }

  Future<_ServerAuthResult?> _exchangeTokenWithServer(String token) async {
    if (token.isEmpty) return null;
    try {
      final response = await _apiService.loginWithAliToken(token);
      if (response['success'] == true) {
        final data = response['data'] ?? {};
        final phone = data['phone']?.toString();
        final userIdValue = data['user_id'];
        final userId = userIdValue is int
            ? userIdValue
            : int.tryParse(userIdValue?.toString() ?? '');
        return _ServerAuthResult(token: token, phone: phone, userId: userId);
      }
      throw Exception(response['error'] ?? 'login_with_token_failed');
    } catch (e) {
      if (kDebugMode) {
        print('登录 token 发送到服务器失败: $e');
      }
      return null;
    }
  }

  void _setStatus(String text) {
    _updateState(() {
      _status = text;
    });
  }

  void _updateState(VoidCallback updater) {
    if (mounted) {
      setState(updater);
    } else {
      updater();
    }
  }

  void _disposeSdkIfNeeded() {
    if (!_isInitialized) return;
    AliAuth.dispose().catchError((error) {
      if (kDebugMode) {
        print('dispose 调用失败: $error');
      }
    }).whenComplete(() {
      _isInitialized = false;
    });
  }

  AliAuthModel _buildFullScreenConfig() {
    return AliAuthModel(
      ApiKeys.aliAuthAndroidSk,
      ApiKeys.aliAuthIosSk,
      // 基本配置
      isDebug: true,
      isDelay: false,
      // 全屏页面
      pageType: PageType.fullPort,
      // 导航栏 / 标题
      navText: '登录',
      navColor: '#00000000', // 透明
      navTextColor: '#FFFFFF',
      
      // 必须设置图片路径，即使隐藏，否则可能报 flutter_assets/null 错误
      navReturnImgPath: 'assets/background_image.jpeg', 
      navReturnHidden: true, 
      
      // Slogan 与 Logo
      logoImgPath: 'assets/background_image.jpeg',
      logoHidden: true, 
      sloganHidden: true, 
      
      // 登录按钮文案
      logBtnText: '一键登录',
      logBtnTextColor: '#FFFFFF',
      logBtnWidth: 300,
      logBtnHeight: 50,
      logBtnOffsetY: 300, 
      
      // 切换账号
      switchAccHidden: true, 

      // 页面背景与模式
      pageBackgroundPath: 'assets/background_image.jpeg', 
      backgroundImageContentMode: ContentMode.scaleAspectFill,
      
      // 行为配置
      autoQuitPage: true, 
      isHiddenToast: false, 
      
      // 隐私协议
      privacyState: false, 
      privacyOffsetY: 10, 
      // 必须设置 Checkbox 图片路径，否则报 flutter_assets/null 错误
      uncheckedImgPath: 'assets/background_image.jpeg',
      checkedImgPath: 'assets/background_image.jpeg',
      checkboxHidden: false, // 隐私协议必须勾选，通常不能完全隐藏 Checkbox，但可以自定义图标
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isInitialized
            ? ElevatedButton(
                onPressed: _oneClickLogin,
                child: const Text('唤起一键登录'),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  
}

class _ServerAuthResult {
  final String token;
  final String? phone;
  final int? userId;

  const _ServerAuthResult({
    required this.token,
    this.phone,
    this.userId,
  });
}

