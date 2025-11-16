import 'package:flutter/material.dart';
import '../widgets/liquid_glass_card.dart';
import '../config/api_keys.dart';
import '../services/localization_service.dart';
import '../services/api_service.dart';
import 'products_page.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalizationService _localizationService = LocalizationService();
  final ApiService _apiService = ApiService();
  String _selectedLanguage = 'zh';
  String _selectedTheme = 'system';
  
  // 使用统计
  int _usedCharacters = 1512;
  int _totalCharacters = 10000;
  bool _isMember = false;
  bool _isMembershipExpanded = true;
  
  @override
  void initState() {
    super.initState();
    _selectedLanguage = _localizationService.currentLocale.languageCode;
    _loadUsageStats();
  }

  Widget _buildUsageInfoTile({
    required String label,
    required String value,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUsageStats() async {
    try {
      final stats = await _apiService.getUserUsageStats();
      if (mounted) {
        setState(() {
          _usedCharacters = stats['used_characters'] ?? 0;
          _totalCharacters = stats['total_characters'] ?? 10000;
          _isMember = stats['is_member'] ?? false;
        });
      }
    } catch (e) {
      // 如果API失败，使用默认值
      if (mounted) {
        // 可以在这里显示错误提示
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Figma 颜色
    final backgroundColor = 
    isDark
        ? const Color(0xFF191815) // rgb(25, 24, 21)
        : const Color(0xFFEEEFDF); // rgb(238, 238, 253)
    
    final textColor = isDark
        ? const Color(0xFFF1EEE3) // rgb(241, 238, 227)
        : const Color(0xFF191815);
    
    final cardColor = isDark
        ? const Color(0xFF191815)
        : const Color(0xFFF1EEE3);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 标题
            Text(
              'Settings',
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            
            // 用户信息卡片
            _buildUserInfoCard(textColor, cardColor),
            const SizedBox(height: 16),
            
            // 使用情况卡片
            _buildUsageStatsCard(textColor, cardColor),
            const SizedBox(height: 16),
            
            // 会员升级卡片
            _buildMembershipCard(textColor, cardColor),
            const SizedBox(height: 32),
            
            // 隐私协议卡片 (基于 settingg-structure.json)
            _buildSettingCard(
              icon: Icons.privacy_tip,
              title: '隐私协议',
              subtitle: 'Privacy Policy',
              cardColor: cardColor,
              textColor: textColor,
              onTap: () => _showPrivacyPolicy(),
            ),
            const SizedBox(height: 16),
            
            // 联系我们卡片
            _buildSettingCard(
              icon: Icons.email,
              title: '联系我们',
              subtitle: ApiKeys.contactEmail,
              cardColor: cardColor,
              textColor: textColor,
              onTap: () => _contactUs(),
            ),
            const SizedBox(height: 16),
            
            // 语言切换
            _buildSettingCard(
              icon: Icons.language,
              title: _selectedLanguage == 'zh' ? '中文' : 'English',
              subtitle: 'Language',
              cardColor: cardColor,
              textColor: textColor,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3742D7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '切换',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () => _showLanguageDialog(),
            ),
            const SizedBox(height: 16),
            
            // 主题切换
            _buildSettingCard(
              icon: Icons.palette,
              title: _getThemeName(),
              subtitle: 'Theme',
              cardColor: cardColor,
              textColor: textColor,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3742D7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '切换',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () => _showThemeDialog(),
            ),
            const SizedBox(height: 16),
            
            // 版本信息
            _buildSettingCard(
              icon: Icons.info,
              title: 'Version',
              subtitle: '1.0.0',
              cardColor: cardColor,
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required Color cardColor,
    required Color textColor,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return LiquidGlassCard(
      borderRadius: 15,
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withOpacity(0.6),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: textColor.withOpacity(0.4),
            ),
        ],
      ),
    );
  }

  String _getThemeName() {
    switch (_selectedTheme) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'system':
      default:
        return 'System Default';
    }
  }

  Future<void> _showLanguageDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('中文'),
              value: 'zh',
              groupValue: _selectedLanguage,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _selectedLanguage,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != _selectedLanguage) {
      setState(() {
        _selectedLanguage = result;
      });
      
      // 切换语言
      final locale = result == 'zh' ? const Locale('zh', 'CN') : const Locale('en', 'US');
      await _localizationService.changeLocale(locale);
      
      // 刷新整个应用
      if (mounted) {
        // 显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result == 'zh' ? '语言已切换为中文' : 'Language changed to English'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 重新构建应用
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // 触发应用重建
            (context as Element).markNeedsBuild();
          }
        });
      }
    }
  }

  Future<void> _showThemeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'light',
              groupValue: _selectedTheme,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'dark',
              groupValue: _selectedTheme,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('System Default'),
              value: 'system',
              groupValue: _selectedTheme,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedTheme = result;
      });
    }
  }

  void _contactUs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Email:'),
            const SizedBox(height: 8),
            SelectableText(
              ApiKeys.contactEmail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私协议'),
        content: SingleChildScrollView(
          child: Text(
            '''隐私协议

更新日期：2024

1. 信息收集
当您使用我们的TTS阅读器应用时，我们会收集您提供的信息。

2. 信息使用
- 提供和维护我们的服务
- 改进我们的服务
- 监控使用情况

3. 数据存储
您的数据安全存储在我们的服务器上。

4. 第三方服务
我们使用第三方服务提供TTS和OCR功能。

5. 联系我们
如有关于隐私政策的问题，请联系：${ApiKeys.contactEmail}
            ''',
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建用户信息卡片
  Widget _buildUserInfoCard(Color textColor, Color cardColor) {
    return LiquidGlassCard(
      borderRadius: 15,
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withOpacity(0.6),
      child: Row(
        children: [
          // 应用图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F5DA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'S',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191815),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isMember ? '会员计划' : '免费计划',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isMember ? 'Premium Plan' : 'Free Plan',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // 刷新按钮
          IconButton(
            onPressed: _loadUsageStats,
            icon: Icon(
              Icons.refresh,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建使用情况卡片
  Widget _buildUsageStatsCard(Color textColor, Color cardColor) {
    final percentage = _totalCharacters > 0 
        ? (_usedCharacters / _totalCharacters * 100).toStringAsFixed(1)
        : '0.0';
    
    return LiquidGlassCard(
      borderRadius: 15,
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withOpacity(0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            '使用情况',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前账户的实际用量与额度',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // 进度条和数值
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalCharacters > 0 
                        ? _usedCharacters / _totalCharacters 
                        : 0,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200]!.withOpacity(0.4),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4CAF50), // 绿色
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(_usedCharacters),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '已用字符',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUsageInfoTile(
                  label: '当前使用',
                  value: _formatNumber(_usedCharacters),
                  textColor: textColor,
                  backgroundColor: cardColor.withOpacity(0.35),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUsageInfoTile(
                  label: '账户限额',
                  value: _formatNumber(_totalCharacters),
                  textColor: textColor,
                  backgroundColor: cardColor.withOpacity(0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 百分比文字
          Text(
            '$percentage% 的字符额度已经被使用。',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建会员升级卡片
  Widget _buildMembershipCard(Color textColor, Color cardColor) {
    return LiquidGlassCard(
      borderRadius: 15,
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withOpacity(0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _isMembershipExpanded = !_isMembershipExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFFFFD700), // 金色
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '加入会员',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: _isMembershipExpanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 16),
            secondChild: const SizedBox(height: 0),
            crossFadeState: _isMembershipExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isMembershipExpanded
                ? Column(
                    key: const ValueKey('membership-expanded'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._getMembershipBenefits().map((benefit) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 6, right: 12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    benefit,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // 跳转到商品页
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ProductsPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '升级',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 获取会员权益列表
  List<String> _getMembershipBenefits() {
    return [
      '每月 1,000,000 可用字符 + 20,000 字符的高级声音',
      '首次开通赠送一次声音克隆',
      '解锁高级声音',
      '解锁单独购买字符包扩充额度',
      '无限图片扫描',
      '无限网页导入',
      '单次OCR扫描支持多张图片',
      '无限文档导入',
      '高级功能',
      '无广告和更好的整体体验',
    ];
  }

  /// 格式化数字（添加千位分隔符）
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}


