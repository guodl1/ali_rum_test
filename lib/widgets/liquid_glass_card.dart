import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// 液态玻璃卡片组件
/// 使用 liquid_glass_renderer 包实现液态玻璃效果
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final double blurIntensity;
  final double thickness;

  const LiquidGlassCard({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 16.0,
    this.blurIntensity = 10.0,
    this.thickness = 15.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 根据主题设置默认颜色
    final defaultBgColor = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0x26FFFFFF);

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: LiquidGlass.withOwnLayer(
        settings: LiquidGlassSettings(
          thickness: thickness,
          blur: blurIntensity,
          glassColor: backgroundColor ?? defaultBgColor,
          lightIntensity: 1.2,
          ambientStrength: 0.3,
        ),
        shape: LiquidRoundedSuperellipse(
          borderRadius: borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              padding: padding ?? const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
