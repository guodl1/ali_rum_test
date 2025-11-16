import 'package:flutter/material.dart';

/// 底部导航栏组件
/// 基于 Figma 设计的导航栏
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Figma 设计颜色
    final navBarColor = 
    isDark
        ? const Color(0xFF191815) // rgb(25, 24, 21)
        : const Color(0xFF191815);
    
    final activeColor = const Color(0xFFEEEFDF); // 
    final inactiveColor = isDark
        ? const Color(0xFFF1EEE3) // rgb(241, 238, 227)
        : const Color(0xFFF1EEE3);

    return Container(
      height: 81,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navBarColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavItem(
              icon: Icons.home,
              index: 0,
              isActive: currentIndex == 0,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
            _buildNavItem(
              icon: Icons.person,
              index: 1,
              isActive: currentIndex == 1,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 81,
        height: 64,
        decoration: BoxDecoration(
          color: isActive ? inactiveColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: inactiveColor,
              size: 28,
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建加号按钮 - 参考 home_page.dart 的加号按钮样式
  Widget _buildAddButton({
    required int index,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 81,
        height: 64,
        decoration: BoxDecoration(
          color: isActive ? inactiveColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 加号按钮 - 白色填充，黑色加号
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.black,
                size: 20,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
