import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/liquid_glass_card.dart';
import '../services/payment_service.dart';
import '../services/user_service.dart';
import '../services/platform_login_service.dart';

/// 商品/升级页面
class ProductsPage extends StatefulWidget {
  const ProductsPage({Key? key}) : super(key: key);

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int _selectedPlanIndex = 0;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _userService.addListener(_onUserUpdate);
    // Refresh profile when entering page
    _userService.fetchProfile();
  }

  @override
  void dispose() {
    _userService.removeListener(_onUserUpdate);
    super.dispose();
  }

  void _onUserUpdate() {
    if (mounted) setState(() {});
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

    final user = _userService.currentUser;
    final isVip = user?.membershipType == 'VIP' && 
                  user?.membershipExpiry != null && 
                  user!.membershipExpiry!.isAfter(DateTime.now());

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
          '升级会员',
          style: TextStyle(color: textColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 会员状态卡片
              if (_userService.isLoggedIn) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isVip ? const Color(0xFFFFD700).withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isVip ? const Color(0xFFFFD700) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isVip ? const Color(0xFFFFD700) : Colors.grey,
                        child: Icon(
                          isVip ? Icons.star : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.username ?? '用户',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isVip 
                                ? 'VIP 有效期至: ${DateFormat('yyyy-MM-dd').format(user!.membershipExpiry!)}'
                                : '当前为普通用户',
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 标题
              Text(
                '选择会员计划',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '解锁更多功能，享受更好的体验',
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // 会员计划列表
              ..._buildPlanCards(textColor, backgroundColor),
              
              const SizedBox(height: 30),
              
              // 购买按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    _handlePurchase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _userService.isLoggedIn ? '立即购买' : '登录并购买',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 说明文字
              Text(
                '购买后立即生效，支持随时取消',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPlanCards(Color textColor, Color backgroundColor) {
    final plans = [
      {
        'name': '月度会员',
        'price': '¥29',
        'period': '/月',
        'features': [
          '每月 1,000,000 可用字符',
          '20,000 字符的高级声音',
          '首次开通赠送一次声音克隆',
          '解锁高级声音',
          '无限图片扫描',
          '无限网页导入',
          '无限文档导入',
        ],
      },
      {
        'name': '年度会员',
        'price': '¥299',
        'period': '/年',
        'originalPrice': '¥348',
        'features': [
          '每月 1,000,000 可用字符',
          '20,000 字符的高级声音',
          '首次开通赠送一次声音克隆',
          '解锁高级声音',
          '无限图片扫描',
          '无限网页导入',
          '无限文档导入',
          '节省 ¥49（相比月度）',
        ],
        'isPopular': true,
      },
    ];

    return plans.asMap().entries.map((entry) {
      final index = entry.key;
      final plan = entry.value;
      final isSelected = _selectedPlanIndex == index;
      final isPopular = plan['isPopular'] == true;
      final isPremium = plan['isPremium'] == true;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlanIndex = index;
            });
          },
          child: LiquidGlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(24),
            backgroundColor: backgroundColor.withOpacity(0.6),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标签
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '最受欢迎',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '超值推荐',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isPopular || isPremium) const SizedBox(height: 12),
                    
                    // 计划名称
                    Text(
                      plan['name'] as String,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // 价格
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan['price'] as String,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          plan['period'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        if (plan['originalPrice'] != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            plan['originalPrice'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor.withOpacity(0.5),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // 功能列表
                    ...(plan['features'] as List<String>).map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF4CAF50),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
                
                // 选中标记
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _handlePurchase() async {
    // Check login first
    if (!_userService.isLoggedIn) {
      final success = await _showLoginDialog();
      if (!success) return;
    }

    final plans = [
      {'name': '月度会员', 'price': '29.00'},
      {'name': '年度会员', 'price': '299.00'},
    ];
    
    if (_selectedPlanIndex >= plans.length) return;
    
    final plan = plans[_selectedPlanIndex];
    final name = plan['name']!;
    final price = plan['price']!;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final paymentService = PaymentService();
      final userId = _userService.currentUser!.id;
      
      final result = await paymentService.payWithAlipay(
        amount: price,
        subject: '听阅 - $name',
        userId: userId,
      );

      // Hide loading
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('支付成功！'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh profile to update membership status
          await _userService.fetchProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '支付失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showLoginDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('购买会员需要先登录账号，是否立即登录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              bool success = false;
              try {
                if (PlatformLoginService.isHarmonyOS) {
                  success = await _userService.loginWithHuawei();
                } else {
                  // TODO: Implement Ali login UI flow if needed, or just call loginWithAli
                  // For now, we assume HarmonyOS flow or generic
                  // If not HarmonyOS, maybe show a toast saying not supported yet or mock login
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('当前平台暂不支持一键登录')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Login error: $e');
              }

              // Hide loading
              if (mounted && Navigator.canPop(context)) {
                Navigator.of(context).pop(); // Pop loading dialog
              }
              
              if (success) {
                 if (mounted) {
                   Navigator.of(context).pop(true); // Pop main dialog with true
                 }
              } else {
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('登录失败，请重试')),
                    );
                 }
              }
            },
            child: const Text('登录'),
          ),
        ],
      ),
    ) ?? false;
  }
}

