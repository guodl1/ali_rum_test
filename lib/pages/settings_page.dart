import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/liquid_glass_card.dart';
import '../config/api_keys.dart';
import '../services/localization_service.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalizationService _localizationService = LocalizationService();
  String _selectedLanguage = 'zh';
  String _selectedTheme = 'system';
  
  @override
  void initState() {
    super.initState();
    _selectedLanguage = _localizationService.currentLocale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 通用设置
              Text(
                'General',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.language,
                title: 'Language',
                subtitle: _selectedLanguage == 'zh' ? 'Chinese' : 'English',
                onTap: () => _showLanguageDialog(),
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.palette,
                title: 'Theme',
                subtitle: _getThemeName(),
                onTap: () => _showThemeDialog(),
              ),
              const SizedBox(height: 24),
              // 关于
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.email,
                title: 'Contact Us',
                subtitle: ApiKeys.contactEmail,
                onTap: () => _contactUs(),
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () => _showPrivacyPolicy(),
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.description,
                title: 'User Agreement',
                onTap: () => _showUserAgreement(),
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                icon: Icons.info,
                title: 'Version',
                subtitle: '1.0.0',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return LiquidGlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PolicyPage(
          title: 'Privacy Policy',
          content: '''
Privacy Policy

Last updated: 2024

1. Information Collection
We collect information you provide directly to us when using our TTS Reader application.

2. How We Use Your Information
- To provide and maintain our service
- To improve our service
- To monitor usage

3. Data Storage
Your data is stored securely on our servers.

4. Third-Party Services
We use third-party services for TTS and OCR functionality.

5. Contact Us
If you have questions about this Privacy Policy, please contact us at ${ApiKeys.contactEmail}
          ''',
        ),
      ),
    );
  }

  void _showUserAgreement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PolicyPage(
          title: 'User Agreement',
          content: '''
User Agreement

Last updated: 2024

1. Acceptance of Terms
By using TTS Reader, you agree to these terms.

2. Use of Service
You may use our service for lawful purposes only.

3. User Content
You retain ownership of content you upload.

4. Prohibited Activities
- Uploading illegal content
- Attempting to hack or disrupt the service
- Violating others' rights

5. Termination
We may terminate your access if you violate these terms.

6. Changes to Terms
We may modify these terms at any time.

7. Contact
For questions, contact us at ${ApiKeys.contactEmail}
          ''',
        ),
      ),
    );
  }
}

/// 协议页面
class PolicyPage extends StatelessWidget {
  final String title;
  final String content;

  const PolicyPage({
    Key? key,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          content,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}
