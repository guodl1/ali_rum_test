import 'dart:async';
import 'package:flutter/material.dart';
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

class _LoginPageState extends State<LoginPage> {
  final LocalizationService _localizationService = LocalizationService();
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  @override
  void dispose() {

    super.dispose();
  }

  /// 初始化阿里云一键登录SDK
  Future<void> _initializeAuth() async {
    try {
      // 初始化 SDK：使用 AliAuth 的 Dart API
      // 请在 `lib/config/api_keys.dart` 中填写真实的 SK
      await AliAuth.initSdk(AliAuthModel(
        ApiKeys.aliAuthAndroidSk,
        ApiKeys.aliAuthIosSk,
        isDebug: true,
      ));
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('初始化阿里云一键登录失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  /// 处理认证结果
  void _handleAuthResult(Map<String, dynamic>? result) {
    if (result == null) return;

    final code = result['code'] ?? 'unknown';
    
    if (code == '600000') {
      // 登录成功
      final token = result['token'];
      final phoneNumber = result['phoneNumber'];
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录成功: $phoneNumber')),
        );
        
        // 返回上一页
        Navigator.of(context).pop(true);
      }
    } else {
      // 登录失败或取消
      String message = '登录失败';
      
      switch (code) {
        case '700000':
          message = '用户取消登录';
          break;
        case '700001':
          message = '用户切换账号';
          break;
        default:
          message = '登录失败: $code';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 调用一键登录（使用 AliAuth.login）
      // 结果会通过监听器回调处理
      await AliAuth.login();
    } catch (e) {
      print('一键登录错误: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '登录失败: $e';
          _isLoading = false;
        });
      }
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

