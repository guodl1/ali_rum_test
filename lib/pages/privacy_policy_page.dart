import 'package:flutter/material.dart';
import '../config/api_keys.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF191815) : const Color(0xFFEEEFDF);
    final textColor = isDark ? const Color(0xFFF1EEE3) : const Color(0xFF191815);

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
          '隐私政策',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '听阅隐私政策',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '更新日期：2025年',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: '1. 服务提供商',
              content: '听阅软件由深圳市流创嘉科技有限公司（以下简称"我们"）提供。我们非常重视您的隐私保护。',
              textColor: textColor,
            ),
            _buildSection(
              title: '2. 信息收集',
              content: '当您使用我们的服务时，我们可能会收集以下信息：\n'
                  '- 账户信息：如您的手机号码（用于登录）。\n'
                  '- 使用数据：如您上传的文本、音频生成记录等。\n'
                  '- 设备信息：如设备型号、操作系统版本等。',
              textColor: textColor,
            ),
            _buildSection(
              title: '3. 信息使用',
              content: '我们收集的信息将用于：\n'
                  '- 提供、维护和改进我们的服务。\n'
                  '- 处理您的请求和交易。\n'
                  '- 发送服务通知和更新。\n'
                  '- 防止欺诈和滥用。',
              textColor: textColor,
            ),
            _buildSection(
              title: '4. 信息共享',
              content: '我们不会向第三方出售您的个人信息。我们仅在以下情况下共享信息：\n'
                  '- 获得您的明确同意。\n'
                  '- 遵守法律法规要求。\n'
                  '- 与我们的服务提供商（如云服务、TTS引擎提供商）合作，以提供服务。',
              textColor: textColor,
            ),
            _buildSection(
              title: '5. 数据安全',
              content: '我们采取合理的安全措施来保护您的信息，防止未经授权的访问、使用或披露。您的数据存储在安全的服务器上。',
              textColor: textColor,
            ),
            _buildSection(
              title: '6. 联系我们',
              content: '如果您对本隐私政策有任何疑问，请联系我们：\n'
                  '邮箱：${ApiKeys.contactEmail}\n'
                  '公司：深圳市流创嘉科技有限公司',
              textColor: textColor,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: textColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
