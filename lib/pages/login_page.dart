import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ali_auth/ali_auth.dart';
import '../config/api_keys.dart';
import '../widgets/liquid_glass_card.dart';
// localization handled elsewhere
import '../services/api_service.dart';

/// 登录页面
/// 使用阿里云一键登录服务
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;
  String? _errorMessage;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeSdkIfNeeded();
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

  /// 一键登录（SDK 自动管理 loading 和页面退出）
  Future<void> _oneClickLogin() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SDK未初始化，请稍后重试')),
      );
      return;
    }

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
        final phoneFromClient = parsed['phone'];

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

        final phoneToPrint = phoneFromClient ?? serverPhone;
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
      // 全屏页面（适配当前 LoginPage）
      pageType: PageType.fullPort,
      // 导航栏 / 标题
      navText: '登录',
      navColor: '#4CAF50',
      navTextColor: '#FFFFFF',
      // Slogan 与 Logo
      sloganText: '一键登录，快速开始',
      logoImgPath: '',
      // 登录按钮文案
      logBtnText: '一键登录',
      logBtnTextColor: '#FFFFFF',
      // 页面背景与模式
      // 注意：pageBackgroundPath 需要使用相对于 assets 的路径（去掉 'assets/' 前缀）
      // 如果设置为空字符串，SDK 会使用默认背景，避免 FileNotFoundException
      pageBackgroundPath: 'background_image.jpeg', // 使用相对于 assets 的路径
      backgroundImageContentMode: ContentMode.scaleAspectFill,
      // 行为配置
      autoQuitPage: true, // 自动退出页面，登录成功或失败后自动关闭授权页
      isHiddenToast: false, // 显示 SDK 内置 Toast
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF191815)
        : const Color(0xFFEEEFDF);
    
    final textColor = isDark
        ? const Color(0xFFF1EEE3)
        : const Color(0xFF191815);

    

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '登录',
          style: TextStyle(color: textColor),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 响应式布局：根据屏幕高度调整间距
            final screenHeight = constraints.maxHeight;
            final isSmallScreen = screenHeight < 600;
            final topPadding = isSmallScreen ? 20.0 : 40.0;
            final titleSpacing = isSmallScreen ? 30.0 : 60.0;
            
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: topPadding),
                    
                    // 标题
                    Text(
                      '欢迎使用',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.08,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '一键登录，快速开始',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        color: textColor.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: titleSpacing),
              
                    // 登录卡片
                    LiquidGlassCard(
                      borderRadius: 20,
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
                      backgroundColor: backgroundColor.withOpacity(0.6),
                      child: Column(
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // 一键登录按钮
                          // SDK 会自动管理 loading 状态，无需手动显示
                          SizedBox(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.07,
                            child: ElevatedButton(
                              onPressed: !_isInitialized ? null : _oneClickLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                '一键登录',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.045,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          if (_status.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _status,
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: MediaQuery.of(context).size.width * 0.035,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          
                          if (!_isInitialized) ...[
                            const SizedBox(height: 16),
                            Text(
                              '正在初始化...',
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: MediaQuery.of(context).size.width * 0.035,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isSmallScreen ? 20.0 : 40.0),
                    
                    // 说明文字
                    Text(
                      '使用本机号码一键登录，无需输入密码',
                      style: TextStyle(
                        color: textColor.withOpacity(0.6),
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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

