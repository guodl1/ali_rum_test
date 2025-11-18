import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ali_auth/ali_auth.dart';
import '../config/api_keys.dart';
import '../widgets/liquid_glass_card.dart';
import '../services/localization_service.dart';

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
  int _screenWidth = 0;
  int _screenHeight = 0;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _calculateScreenMetrics();
    _initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quitPageIfPossible();
    _disposeSdkIfNeeded();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _quitPageIfPossible();
    }
  }

  void _calculateScreenMetrics() {
    final view = PlatformDispatcher.instance.views.first;
    _screenWidth = (view.physicalSize.width / view.devicePixelRatio).floor();
    _screenHeight = (view.physicalSize.height / view.devicePixelRatio).floor();
  }

  /// 初始化阿里云一键登录SDK（参考文档要求：先监听再初始化）
  Future<void> _initializeAuth() async {
    try {
      // 2. 初始化 SDK 并配置 UI
      // 1. 先注册监听，确保在任何 login 之前
      await AliAuth.loginListen(onEvent: _handleLoginEvent);

      await AliAuth.initSdk(_buildFullScreenConfig());

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

  /// 一键登录（使用 loginListen 方法）
  Future<void> _oneClickLogin() async {
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

  void _handleLoginEvent(dynamic rawEvent) {
    final event = _normalizeEvent(rawEvent);
    final code = event['code'] ?? '';
    final message = event['msg'] ?? '';
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
        _quitPageIfPossible();
        showToast(Colors.red);
        _setStatus(message.isEmpty ? '用户取消' : message);
        _stopLoadingIfNeeded(errorMessage: message.isEmpty ? '用户取消' : message);
        break;

      case '700002': // 点击登录按钮
      case '700003': // 勾选 CheckBox
      case '700004': // 点击协议
      case '700005': // 点击第三方按钮
        showToast(Colors.blueGrey);
        _setStatus('事件($code): $message');
        break;

      case '600000': // 登录成功
        _quitPageIfPossible();
        final parsed = _parseLoginData(eventData);
        if (kDebugMode && parsed.phone != null) {
          print('AliAuth 登录手机号: ${parsed.phone}');
        }
        if (mounted) {
          setState(() {
            _isLoading = false; // 登录成功后停止loading
            _errorMessage = null;
            _status = '登录成功';
          });
          Navigator.of(context).pop({
            'token': parsed.token,
            if (parsed.phone != null) 'phone': parsed.phone,
          });
        }
        break;

      default:
        showToast(Colors.orange);
        _setStatus('未知事件($code): $message');
        break;
    }
  }

  Map<String, String> _normalizeEvent(dynamic rawEvent) {
    if (rawEvent is Map) {
      return rawEvent.map((key, value) => MapEntry(
            key.toString(),
            value?.toString() ?? '',
          ));
    }
    if (rawEvent == null) return {};
    return {'code': rawEvent.toString(), 'msg': rawEvent.toString()};
  }

  ({String token, String? phone}) _parseLoginData(dynamic data) {
    if (data is Map) {
      final token = data['token']?.toString() ?? '';
      final phone =
          data['phoneNumber']?.toString() ?? data['mobile']?.toString();
      if (kDebugMode) {
        print('AliAuth 登录手机号: $phone');
      }
      return (token: token, phone: phone);
    }
    final token = data?.toString() ?? '';
    return (token: token, phone: null);
  }

  void _setStatus(String text) {
    if (!mounted) return;
    setState(() {
      _status = text;
    });
  }

  void _stopLoadingIfNeeded({String? errorMessage}) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = errorMessage;
    });
  }

  void _quitPageIfPossible() {
    if (!_isInitialized) return;
    AliAuth.quitPage().catchError((error) {
      if (kDebugMode) {
        print('quitPage 调用失败: $error');
      }
    });
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
    final unit = (_screenHeight * 0.06).floor();
    final logBtnHeight = (unit * 1.1).floor();
    return AliAuthModel(
      ApiKeys.aliAuthAndroidSk,
      ApiKeys.aliAuthIosSk,
      isDebug: kDebugMode,
      pageType: PageType.fullPort,
      statusBarColor: "#FFFFFF",
      isStatusBarHidden: false,
      navColor: "#FFFFFF",
      navText: "本机号码一键登录",
      navTextColor: "#191919",
      navTextSize: 18,
      navReturnHidden: false,
      numberColor: "#191919",
      numberSize: 26,
      logBtnText: "本机号码一键登录",
      logBtnTextSize: 16,
      logBtnTextColor: "#FFFFFF",
      logBtnOffsetY: logBtnHeight * 2,
      logBtnHeight: logBtnHeight,
      logBtnBackgroundPath: "",
      logoHidden: true,
      privacyState: false,
      protocolOneName: "《用户协议》",
      protocolOneURL: "https://tunderly.com",
      protocolTwoName: "《隐私政策》",
      protocolTwoURL: "https://jokui.com",
      protocolCustomColor: "#4CAF50",
      protocolColor: "#9E9E9E",
      protocolLayoutGravity: Gravity.centerHorizntal,
      logBtnToastHidden: false,
      sloganText: "欢迎使用阿里一键登录",
      sloganTextColor: "#9E9E9E",
      sloganHidden: false,
      sloganTextSize: 12,
      privacyTextSize: 12,
      privacyBefore: "我已阅读并同意",
      privacyEnd: "",
      switchAccText: "使用其它号码登录",
      switchAccTextColor: "#4CAF50",
      switchAccTextSize: 14,
      screenOrientation: -1,
      pageBackgroundPath: "assets/background_image.jpeg",
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
                              onPressed: _isLoading || !_isInitialized ? null : _oneClickLogin,
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

