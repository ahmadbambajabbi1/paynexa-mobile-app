import 'package:flutter/material.dart';

import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../utils/transaction_ui.dart';
import '../utils/currency.dart';

class TransactionListTileCard extends StatelessWidget {
  const TransactionListTileCard({
    super.key,
    required this.row,
    required this.selfUserId,
    required this.onTap,
    this.currency,
  });

  final TransactionListItem row;
  final String selfUserId;
  final VoidCallback onTap;
  final String? currency;

  bool get _isPublic => row.workflow == 'PUBLIC_SHAREABLE';

  bool get _landOrEstate =>
      row.type.contains('ESTATE') || row.type.contains('LAND');

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) {
      return iso;
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Color _statusBg(String status) {
    if (status == 'COMPLETED' || status == 'CLOSED') {
      return Colors.blue.shade50;
    }
    if (status == 'DISPUTED') {
      return Colors.red.shade50;
    }
    if (status == 'FUNDED' ||
        status == 'IN_PROGRESS' ||
        status == 'INSPECTION') {
      return Colors.blue.shade50;
    }
    return AppColors.gambianSand.withValues(alpha: 0.6);
  }

  Color _statusFg(String status) {
    if (status == 'COMPLETED' || status == 'CLOSED') {
      return AppColors.primaryColorBlack;
    }
    if (status == 'DISPUTED') {
      return Colors.red.shade800;
    }
    if (status == 'FUNDED' ||
        status == 'IN_PROGRESS' ||
        status == 'INSPECTION') {
      return AppColors.primaryColorBlack;
    }
    return AppColors.gambianEarth;
  }

  @override
  Widget build(BuildContext context) {
    final role = row.buyerId == selfUserId ? 'Buying' : 'Selling';
    final itemTitle = row.productTitle.trim().isNotEmpty
        ? row.productTitle.trim()
        : 'Transaction ${row.id.substring(0, row.id.length >= 8 ? 8 : row.id.length)}';
    final title = '$role $itemTitle';
    final subtitle =
        '${_isPublic ? 'Shareable sale' : formatTransactionType(row.type)} · Updated ${_shortDate(row.updatedAt)}';
    final progress = statusApproxProgress(row.status) / 100;
    const accent = AppColors.primaryColorBlack;
    final iconBg = _isPublic
        ? Colors.blue.shade50
        : _landOrEstate
        ? AppColors.gambianSand
        : Colors.blue.shade50;
    final iconFg = _isPublic
        ? AppColors.primaryColorBlack
        : _landOrEstate
        ? AppColors.gambianEarth
        : AppColors.primaryColorBlack;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EBF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: iconBg,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _isPublic
                          ? Icons.link_rounded
                          : _landOrEstate
                          ? Icons.home_rounded
                          : Icons.inventory_2_outlined,
                      color: iconFg,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            height: 1.18,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8EBF2)),
                    ),
                    child: Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      moneyText(row.amount, currency),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(
                    label: formatStatus(row.status),
                    background: _statusBg(row.status),
                    foreground: _statusFg(row.status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  color: accent,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 136),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _WorkflowChip extends StatelessWidget {
  const _WorkflowChip({required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublic ? Colors.blue.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPublic ? 'Link' : 'Escrow',
        style: TextStyle(
          color: AppColors.primaryColorBlack,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// // import '../models/transaction_models.dart';
// import '../theme/app_colors.dart';
// import '../utils/transaction_ui.dart';
