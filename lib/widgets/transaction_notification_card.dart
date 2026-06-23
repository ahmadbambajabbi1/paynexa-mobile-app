import 'package:flutter/material.dart';

import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../utils/notification_ui.dart';

/// Notification card — mirrors escrow_web notifications page card design.
class TransactionNotificationCard extends StatelessWidget {
  const TransactionNotificationCard({
    super.key,
    required this.item,
    required this.isProcessing,
    required this.onReview,
    this.onAccept,
  });

  final TransactionNotificationItem item;
  final bool isProcessing;
  final VoidCallback onReview;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final style = notificationStatusStyle(item.status);
    final isNew = item.readAt == null;

    return Container(
      decoration: BoxDecoration(
        color: style.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isNew)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryColorBlack,
                      AppColors.primaryColorBlack.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: style.badgeBg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        style.icon,
                        style: TextStyle(
                          color: style.badgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.message,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MetaChip(
                                label: item.role,
                                bg: Colors.white.withValues(alpha: 0.6),
                                border: Colors.grey.shade200,
                                textColor: Colors.grey.shade700,
                                showDot: true,
                              ),
                              _MetaChip(
                                label: item.status.replaceAll('_', ' '),
                                bg: style.badgeBg,
                                border: style.border,
                                textColor: style.badgeText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      _NewBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _ReviewButton(onPressed: onReview),
                    if (item.status == 'AWAITING_ACCEPTANCE' && onAccept != null)
                      _AcceptButton(
                        isProcessing: isProcessing,
                        onPressed: onAccept!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewBadge extends StatefulWidget {
  @override
  State<_NewBadge> createState() => _NewBadgeState();
}

class _NewBadgeState extends State<_NewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gambianRed, Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FadeTransition(
                  opacity: Tween(begin: 0.75, end: 0.0).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'New',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.bg,
    required this.border,
    required this.textColor,
    this.showDot = false,
  });

  final String label;
  final Color bg;
  final Color border;
  final Color textColor;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primaryColorBlack,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColorBlack,
                AppColors.primaryColorBlack.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColorBlack.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Review Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({
    required this.isProcessing,
    required this.onPressed,
  });

  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isProcessing ? null : onPressed,
      icon: isProcessing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check, size: 16),
      label: Text(isProcessing ? 'Accepting...' : 'Accept'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gambianGreen,
        backgroundColor: AppColors.gambianGreen.withValues(alpha: 0.05),
        side: const BorderSide(color: AppColors.gambianGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
