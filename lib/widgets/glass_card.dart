// import 'package:flutter/material.dart';

// /// Visual cousin of [escrow_web] `.glass-panel` / `cardPanel`.
// class GlassCard extends StatelessWidget {
//   const GlassCard({super.key, required this.child, this.padding});

//   final Widget child;
//   final EdgeInsetsGeometry? padding;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: padding ?? const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.95),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.grey.shade100),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 24,
//             offset: const Offset(0, 12),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }
// }
import 'package:flutter/material.dart';

/// Refined glass card — soft white surface with subtle depth.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        border: Border.all(color: const Color(0xFFEEF0F4), width: 1),
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