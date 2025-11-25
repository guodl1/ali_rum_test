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
      // ========== 基本配置 ==========
      isDebug: true,
      isDelay: false,
      pageType: PageType.dialogPort, // 半屏弹窗模式
      
      // ========== 弹窗配置 ==========
      dialogWidth: 320,
      dialogHeight: 500,
      dialogOffsetY: 0, // 距离底部的偏移
      dialogBottom: true, // 从底部弹出
      
      // ========== 状态栏配置 ==========
      statusBarColor: '#FFFFFF', // 白色状态栏
      isStatusBarHidden: false, // 显示状态栏
      lightColor: false, // 深色文字（浅色背景）
      
      // ========== 导航栏配置 ==========
      navText: '一键登录',
      navTextColor: '#333333', // 深色文字
      navTextSize: 18,
      navColor: '#FFFFFF', // 白色导航栏
      navHidden: false, // 显示导航栏
      navReturnImgPath: 'assets/background.jpg', // 返回按钮图标
      navReturnHidden: false, // 显示返回按钮
      navReturnImgWidth: 24,
      navReturnImgHeight: 24,
      
      // ========== Logo 配置 ==========
      logoImgPath: 'assets/background.jpg', 
      logoHidden: false, // 显示 Logo
      logoWidth: 70,
      logoHeight: 70,
      logoOffsetY: 60, // 距离顶部 60
      
      // ========== 手机号码配置 ==========
      numberColor: '#1a1a1a', // 深黑色号码
      numberSize: 22,
      numFieldOffsetY: 160, // Logo 下方
      
      // ========== Slogan 配置 ==========
      sloganText: '欢迎使用一键登录',
      sloganTextColor: '#666666',
      sloganTextSize: 12,
      sloganHidden: false, // 显示 Slogan
      sloganOffsetY: 135, // Logo 正下方
      
      // ========== 登录按钮配置 ==========
      logBtnText: '本机号码一键登录',
      logBtnTextColor: '#FFFFFF',
      logBtnTextSize: 16,
      logBtnWidth: 280,
      logBtnHeight: 48,
      logBtnOffsetY: 230, // 号码下方
      logBtnMarginLeftAndRight: 20,
      logBtnBackgroundPath: 'assets/background.jpg', // 可以设置按钮背景图
      
      // ========== 切换账号配置 ==========
      switchAccHidden: true, // 隐藏切换账号按钮
      
      // ========== 隐私协议配置 ==========
      privacyState: false, // 默认未勾选
      checkboxHidden: false, // 显示复选框
      checkBoxWidth: 18,
      checkBoxHeight: 18,
      uncheckedImgPath: 'assets/background.jpg', // 未选中图标
      checkedImgPath: 'assets/background.jpg', // 选中图标
      
      // 隐私协议文本配置 - 放在登录按钮下方
      privacyOffsetY: 310, // 登录按钮下方 (230 + 48 + 32)
      privacyTextSize: 10,
      privacyMargin: 20, // 左右边距
      
      // 隐私协议文本内容
      privacyBefore: '登录即同意',
      privacyEnd: '并授权获取本机号码',
      
      // 运营商协议颜色
      protocolOwnColor: '#3E7EFF', // 运营商协议蓝色
      protocolCustomColor: '#3E7EFF', // 自定义协议颜色
      
      // 自定义协议
      protocolOneName: '《用户协议》',
      protocolOneURL: 'https://tingyue.top/user-agreement',
      protocolTwoName: '《隐私政策》',
      protocolTwoURL: 'https://tingyue.top/privacy-policy',
      
      // ========== 页面背景配置 ==========
      backgroundColor: '#FFFFFF', // 白色背景
      
      // ========== 行为配置 ==========
      autoQuitPage: true, // 登录成功/用户取消后自动关闭页面
      closeAuthPageReturnBack: false, // 关闭页面时不返回上一页（由 pop 处理）
      tapAuthPageMaskClosePage: true, // 点击遮罩关闭页面
      
      // ========== Toast 配置 ==========
      isHideToast: false, // 显示 Toast 提示
      toastText: '请先阅读并同意用户协议',
      toastBackground: '#DD000000', // 半透明黑色
      toastColor: '#FFFFFF',
      toastPadding: 16,
      toastMarginBottom: 100,
      toastPositionMode: 'bottom',
      toastDelay: 2,
      logBtnToastHidden: false, // 显示登录按钮 Toast
      
      // ========== 加载动画配置 ==========
      autoHideLoginLoading: true, // 自动隐藏加载动画
      loadingImgPath: 'assets/background.jpg', // 加载动画图标
      
      // ========== 协议页面WebView配置 ==========
      webViewStatusBarColor: '#FFFFFF',
      webNavColor: '#FFFFFF',
      webNavTextColor: '#333333',
      webNavTextSize: 18,
      webSupportedJavascript: true,
      
      // ========== 隐私弹窗配置（二次确认） ==========
      privacyAlertIsNeedShow: false, // 不显示二次隐私弹窗
      privacyAlertIsNeedAutoLogin: true, // 同意后自动登录
      privacyAlertMaskIsNeedShow: true, // 显示遮罩
      privacyAlertMaskAlpha: 0.5,
      privacyAlertMaskColor: '#000000',
      tapPrivacyAlertMaskCloseAlert: false, // 点击遮罩不关闭弹窗
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

