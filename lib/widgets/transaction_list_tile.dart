import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../utils/transaction_ui.dart';

class TransactionListTileCard extends StatelessWidget {
  const TransactionListTileCard({
    super.key,
    required this.row,
    required this.selfUserId,
    required this.onTap,
  });

  final TransactionListItem row;
  final String selfUserId;
  final VoidCallback onTap;

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
    final title = row.productTitle.trim().isNotEmpty
        ? row.productTitle.trim()
        : 'Transaction ${row.id.substring(0, row.id.length >= 8 ? 8 : row.id.length)}';
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
          padding: const EdgeInsets.all(16),
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
                    width: 48,
                    height: 48,
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
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _WorkflowChip(isPublic: _isPublic),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$role · ${formatTransactionType(row.type)} · ${_shortDate(row.updatedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$kCurrencyPrefix${row.amount}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0).toDouble(),
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade100,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBg(row.status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatStatus(row.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _statusFg(row.status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),
                    ],
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
// import '../config/constants.dart';
// import '../models/transaction_models.dart';
// import '../theme/app_colors.dart';
// import '../utils/transaction_ui.dart';

// class TransactionListTileCard extends StatelessWidget {
//   const TransactionListTileCard({
//     super.key,
//     required this.row,
//     required this.selfUserId,
//     required this.onTap,
//   });

//   final TransactionListItem row;
//   final String selfUserId;
//   final VoidCallback onTap;

//   bool get _isPublic => row.workflow == 'PUBLIC_SHAREABLE';

//   String _shortDate(String iso) {
//     final d = DateTime.tryParse(iso);
//     if (d == null) return iso;
//     const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
//     return '${months[d.month - 1]} ${d.day}, ${d.year}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isBuyer = row.buyerId == selfUserId;
//     final role = isBuyer ? 'Buying' : 'Selling';
//     final title = row.productTitle.trim().isNotEmpty
//         ? row.productTitle.trim()
//         : 'Transaction #${row.id.substring(0, row.id.length >= 8 ? 8 : row.id.length)}';
//     final progress = (statusApproxProgress(row.status) / 100).clamp(0.0, 1.0);
//     final statusLabel = _friendlyStatus(row.status);
//     final statusColor = _statusColor(row.status);

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(20),
//         onTap: onTap,
//         child: Container(
//           padding: const EdgeInsets.all(18),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: const Color(0xFFEEF0F6)),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.primaryColorBlack.withValues(alpha: 0.05),
//                 blurRadius: 16,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   _TypeIcon(isPublic: _isPublic),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           title,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w800,
//                             fontSize: 15,
//                             color: Color(0xFF0F172A),
//                             letterSpacing: -0.3,
//                           ),
//                         ),
//                         const SizedBox(height: 3),
//                         Text(
//                           '$role · ${_shortDate(row.updatedAt)}',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey.shade500,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   _StatusBadge(label: statusLabel, color: statusColor),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '$kCurrencyPrefix${row.amount}',
//                           style: const TextStyle(
//                             fontSize: 22,
//                             fontWeight: FontWeight.w900,
//                             color: Color(0xFF0F172A),
//                             letterSpacing: -0.5,
//                           ),
//                         ),
//                         const SizedBox(height: 10),
//                         ClipRRect(
//                           borderRadius: BorderRadius.circular(999),
//                           child: LinearProgressIndicator(
//                             value: progress,
//                             minHeight: 5,
//                             backgroundColor: const Color(0xFFF1F5F9),
//                             valueColor: AlwaysStoppedAnimation<Color>(
//                               _progressColor(row.status),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Container(
//                     width: 36,
//                     height: 36,
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFF8FAFF),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: const Color(0xFFEEF0F6)),
//                     ),
//                     child: Icon(
//                       Icons.chevron_right_rounded,
//                       color: Colors.grey.shade400,
//                       size: 20,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   String _friendlyStatus(String status) {
//     const map = {
//       'AWAITING_ACCEPTANCE': 'Pending Acceptance',
//       'AWAITING_FUNDING': 'Awaiting Payment',
//       'FUNDED': 'Paid',
//       'IN_PROGRESS': 'In Delivery',
//       'INSPECTION': 'Under Review',
//       'COMPLETED': 'Completed',
//       'DISPUTED': 'Disputed',
//       'REFUNDED': 'Refunded',
//       'CLOSED': 'Closed',
//     };
//     return map[status] ?? status.replaceAll('_', ' ').toLowerCase();
//   }

//   Color _statusColor(String status) {
//     if (status == 'COMPLETED') return const Color(0xFF16A34A);
//     if (status == 'DISPUTED') return const Color(0xFFDC2626);
//     if (status == 'REFUNDED') return const Color(0xFF7C3AED);
//     if (status == 'CLOSED') return Colors.grey.shade500;
//     if (status == 'FUNDED' || status == 'IN_PROGRESS' || status == 'INSPECTION') {
//       return AppColors.primaryColorBlack;
//     }
//     return AppColors.gambianEarth;
//   }

//   Color _progressColor(String status) {
//     if (status == 'COMPLETED') return const Color(0xFF16A34A);
//     if (status == 'DISPUTED') return const Color(0xFFDC2626);
//     return AppColors.primaryColorBlack;
//   }
// }

// class _TypeIcon extends StatelessWidget {
//   const _TypeIcon({required this.isPublic});
//   final bool isPublic;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 46,
//       height: 46,
//       decoration: BoxDecoration(
//         color: isPublic
//             ? AppColors.primaryColorBlack.withValues(alpha: 0.08)
//             : AppColors.gambianSand.withValues(alpha: 0.5),
//         borderRadius: BorderRadius.circular(14),
//       ),
//       child: Icon(
//         isPublic ? Icons.link_rounded : Icons.shield_outlined,
//         color: isPublic ? AppColors.primaryColorBlack : AppColors.gambianEarth,
//         size: 22,
//       ),
//     );
//   }
// }

// class _StatusBadge extends StatelessWidget {
//   const _StatusBadge({required this.label, required this.color});
//   final String label;
//   final Color color;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           fontSize: 10,
//           fontWeight: FontWeight.w800,
//           color: color,
//           letterSpacing: 0.2,
//         ),
//       ),
//     );
//   }
// }