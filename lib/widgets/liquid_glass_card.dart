import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';


/// 液态玻璃卡片组件
/// 自动根据平台选择实现：
/// - HarmonyOS: 使用 LiquidGlassCardOhos (liquid_glass_effect)
/// - 其他平台: 使用 _LiquidGlassCardDefault (liquid_glass_renderer)
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
  final bool enableAdvancedEffect;

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
    this.enableAdvancedEffect = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {


    return _LiquidGlassCardDefault(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      blurIntensity: blurIntensity,
      thickness: thickness,
      enableAdvancedEffect: enableAdvancedEffect,
      child: child,
    );
  }
}

class _LiquidGlassCardDefault extends StatelessWidget {
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
  final bool enableAdvancedEffect;

  const _LiquidGlassCardDefault({
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
    this.enableAdvancedEffect = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 根据主题设置默认颜色
    final defaultBgColor = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0x26FFFFFF);

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );

    final shouldUseRenderer = enableAdvancedEffect && !_forceFallback;

    final glassBody = shouldUseRenderer
        ? LiquidGlass.withOwnLayer(
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
            child: content,
          )
        : _FallbackGlass(
            borderRadius: borderRadius,
            blurIntensity: blurIntensity,
            backgroundColor: backgroundColor ?? defaultBgColor,
            child: content,
          );

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: glassBody,
    );
  }

  bool get _forceFallback {
    if (!enableAdvancedEffect) return true;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}

class _FallbackGlass extends StatelessWidget {
  final double borderRadius;
  final double blurIntensity;
  final Color backgroundColor;
  final Widget child;

  const _FallbackGlass({
    required this.borderRadius,
    required this.blurIntensity,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurIntensity,
          sigmaY: blurIntensity,
        ),
        child: Container(
          color: backgroundColor,
          child: child,
        ),
      ),
    );
  }
}
