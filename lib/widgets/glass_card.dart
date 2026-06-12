import 'package:flutter/material.dart';

/// Refined glass card — soft white surface with subtle depth.
/// Supports custom background color.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor, // <-- new parameter
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor; // optional, defaults to white

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white, // use custom color or default white
        // borderRadius: BorderRadius.circular(borderRadius ?? 16),
        // border: Border.all(color: const Color(0xFFEEF0F4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}