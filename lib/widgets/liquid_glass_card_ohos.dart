import 'package:flutter/material.dart';
import 'package:liquid_glass_effect/liquid_glass_effect.dart';

class LiquidGlassCardOhos extends StatelessWidget {
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

  const LiquidGlassCardOhos({
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
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(borderRadius),
          blur: blurIntensity,
          child: Container(
            padding: padding ?? const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
