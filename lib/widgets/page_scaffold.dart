import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pattern_background.dart';

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.bottom,
  });

  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.pageBackground),
            child: SizedBox.expand(),
          ),
          const PatternBackground(opacity: 0.4),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  child,
                  if (bottom != null) ...[
                    const SizedBox(height: 24),
                    bottom!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
