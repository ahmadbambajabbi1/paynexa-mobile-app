import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NotificationStatusStyle {
  const NotificationStatusStyle({
    required this.cardBg,
    required this.border,
    required this.badgeBg,
    required this.badgeText,
    required this.icon,
  });

  final Color cardBg;
  final Color border;
  final Color badgeBg;
  final Color badgeText;
  final String icon;
}

NotificationStatusStyle notificationStatusStyle(String status) {
  final st = status.toLowerCase();
  if (st.contains('pending')) {
    return NotificationStatusStyle(
      cardBg: const Color(0xFFEFF6FF),
      border: AppColors.primaryColorBlack.withValues(alpha: 0.2),
      badgeBg: AppColors.primaryColorBlack.withValues(alpha: 0.1),
      badgeText: AppColors.primaryColorBlack,
      icon: '⏳',
    );
  }
  if (st.contains('accepted') || st.contains('approved')) {
    return NotificationStatusStyle(
      cardBg: const Color(0xFFECFDF5),
      border: AppColors.gambianGreen.withValues(alpha: 0.2),
      badgeBg: AppColors.gambianGreen.withValues(alpha: 0.1),
      badgeText: AppColors.gambianGreen,
      icon: '✓',
    );
  }
  if (st.contains('rejected') || st.contains('failed')) {
    return NotificationStatusStyle(
      cardBg: const Color(0xFFFEF2F2),
      border: AppColors.gambianRed.withValues(alpha: 0.2),
      badgeBg: AppColors.gambianRed.withValues(alpha: 0.1),
      badgeText: AppColors.gambianRed,
      icon: '✕',
    );
  }
  return NotificationStatusStyle(
    cardBg: const Color(0xFFF9FAFB),
    border: Colors.grey.shade200,
    badgeBg: Colors.grey.shade100,
    badgeText: Colors.grey.shade700,
    icon: '•',
  );
}
