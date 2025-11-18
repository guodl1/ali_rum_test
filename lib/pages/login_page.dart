import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ali_auth/ali_auth.dart';
import '../widgets/liquid_glass_card.dart';
import '../services/localization_service.dart';
import '../services/ali_auth_config.dart';

/// 登录页面
/// 使用阿里云一键登录服务
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final LocalizationService _localizationService = LocalizationService();
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _status = '';
  bool _listenerRegistered = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tearDownAliAuth();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AliAuth.quitPage();
    }
  }

  /// 完整初始化：注册监听 + 配置 SDK
  Future<void> _initializeAuth() async {
    try {
      if (!_listenerRegistered) {
        _registerAliAuthListener();
      }

      // 初始化 SDK 配置
      await AliAuth.initSdk(AliAuthConfig.buildFullScreenConfig());

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('初始化阿里云一键登录失败: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '初始化失败: $e';
          _isInitialized = false;
        });
      }
    }
  }

  void _registerAliAuthListener() {
    AliAuth.loginListen(
      type: false,
      onEvent: _handleLoginEvent,
      onError: _handleLoginError,
    );
    _listenerRegistered = true;
  }

  Future<void> _tearDownAliAuth() async {
    try {
      await AliAuth.quitPage();
    } catch (_) {}
    try {
      await AliAuth.dispose();
    } catch (_) {}
    _listenerRegistered = false;
    _isInitialized = false;
  }

  /// 一键登录（使用 loginListen 方法）
  Future<void> _oneClickLogin() async {
    if (!_listenerRegistered) {
      await _initializeAuth();
    }

    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SDK未初始化，请稍后重试')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _status = '';
    });

    try {
      // 参考文档：监听成功后直接调用 login
      await AliAuth.login();
    } catch (e) {
      if (kDebugMode) {
        print('一键登录错误: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '登录失败: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _quitAuthPage() async {
    try {
      await AliAuth.quitPage();
      if (mounted) {
        setState(() {
          _status = '授权页已关闭';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('关闭授权页失败: $e');
      }
    }
  }

  Future<void> _destroyAuthSdk() async {
    await _tearDownAliAuth();
    if (mounted) {
      setState(() {
        _status = 'AliAuth SDK 已释放';
        _errorMessage = null;
      });
    }
  }

  /// 登录成功处理
  void _handleLoginEvent(Map<dynamic, dynamic>? onEvent) async {
    if (kDebugMode) {
      print("----------------> $onEvent <----------------");
    }

    if (onEvent == null) return;

    final code = onEvent['code']?.toString() ?? '';
    final msg = onEvent['msg']?.toString() ?? '';
    final data = onEvent['data'];

    if (code == '600024') {
      // 600024: 需要继续执行 login
      await AliAuth.login();
      return;
    }

    if (msg.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: code == "600000" ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (code == "700005") {
      AliAuth.quitPage();
    }

    if (code == "600000" && data != null) {
      final phoneNumber = data['phoneNumber'] ?? data['mobile'];
      AliAuth.quitPage();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _status = '登录成功';
        });
        Navigator.of(context).pop({
          'token': data['token'],
          'phone': phoneNumber,
        });
      }
      return;
    }

    if (code.isNotEmpty && code != "600000") {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = msg.isNotEmpty ? msg : '登录失败: $code';
          _status = onEvent.toString();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _status = onEvent.toString();
        });
      }
    }
  }

  /// 登录错误处理
  void _handleLoginError(Object? error) {
    if (kDebugMode) {
      print("-------------失败分割线------------$error");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = '登录失败: $error';
        _status = error?.toString() ?? '登录失败';
      });
    }
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

    final localizations = AppLocalizations.of(context)!;

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
                          SizedBox(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.07,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _oneClickLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      '本机号码一键登录',
                                      style: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.045,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _quitAuthPage,
                                  child: const Text('退出授权页'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _destroyAuthSdk,
                                  child: const Text('释放SDK'),
                                ),
                              ),
                            ],
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

