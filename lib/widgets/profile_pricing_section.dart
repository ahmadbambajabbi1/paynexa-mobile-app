// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// import '../api/professional_fees_api.dart';
// import '../config/constants.dart';
// import '../theme/app_colors.dart';
// import 'glass_card.dart';

// class ProfilePricingSection extends StatefulWidget {
//   const ProfilePricingSection({super.key, required this.token});

//   final String token;

//   @override
//   State<ProfilePricingSection> createState() => _ProfilePricingSectionState();
// }

// class _ProfilePricingSectionState extends State<ProfilePricingSection> {
//   ProfessionalFeesResponse? _data;
//   final Map<String, TextEditingController> _controllers = {};
//   bool _loading = true;
//   String? _savingId;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//     });
//     try {
//       final r = await fetchProfessionalFees(widget.token);
//       for (final c in _controllers.values) {
//         c.dispose();
//       }
//       _controllers.clear();
//       for (final i in r.items) {
//         _controllers[i.productTypeId] = TextEditingController(text: i.feeAmount ?? '');
//       }
//       if (mounted) {
//         setState(() {
//           _data = r;
//           _loading = false;
//         });
//       }
//     } catch (_) {
//       if (mounted) {
//         setState(() {
//           _data = null;
//           _loading = false;
//         });
//       }
//     }
//   }

//   @override
//   void dispose() {
//     for (final c in _controllers.values) {
//       c.dispose();
//     }
//     super.dispose();
//   }

//   Future<void> _save(String productTypeId) async {
//     final ctrl = _controllers[productTypeId];
//     if (ctrl == null) return;
//     final raw = ctrl.text.trim();
//     if (raw.isEmpty) return;
//     if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) return;
//     setState(() => _savingId = productTypeId);
//     try {
//       final res = await putProfessionalFee(widget.token, productTypeId, raw);
//       final v = res['feeAmount'];
//       if (v is String) ctrl.text = v;
//     } finally {
//       if (mounted) setState(() => _savingId = null);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return GlassCard(
//         padding: const EdgeInsets.all(20),
//         child: const SizedBox(
//           height: 56,
//           child: Center(child: CircularProgressIndicator()),
//         ),
//       );
//     }
//     final data = _data;
//     if (data == null || data.items.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return GlassCard(
//       padding: const EdgeInsets.all(12),
//       child: LayoutBuilder(
//         builder: (context, c) {
//           return SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: ConstrainedBox(
//               constraints: BoxConstraints(minWidth: c.maxWidth),
//               child: DataTable(
//                 headingRowHeight: 40,
//                 dataRowMinHeight: 48,
//                 columns: [
//                   DataColumn(
//                     label: Text(
//                       'Name',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                   DataColumn(
//                     label: Text(
//                       'Code',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                   DataColumn(
//                     label: Text(
//                       kCurrencyPrefix,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                   DataColumn(label: const SizedBox(width: 72)),
//                 ],
//                 rows: data.items.map((row) {
//                   final controller = _controllers[row.productTypeId] ??=
//                       TextEditingController(text: row.feeAmount ?? '');
//                   return DataRow(
//                     cells: [
//                       DataCell(Text(row.name)),
//                       DataCell(
//                         Text(
//                           row.code,
//                           style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//                         ),
//                       ),
//                       DataCell(
//                         SizedBox(
//                           width: 108,
//                           child: TextField(
//                             controller: controller,
//                             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                             inputFormatters: [
//                               FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
//                             ],
//                             decoration: const InputDecoration(
//                               isDense: true,
//                               border: OutlineInputBorder(),
//                               contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//                             ),
//                           ),
//                         ),
//                       ),
//                       DataCell(
//                         _savingId == row.productTypeId
//                             ? const SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: CircularProgressIndicator(strokeWidth: 2),
//                               )
//                             : FilledButton(
//                                 onPressed: () => _save(row.productTypeId),
//                                 style: FilledButton.styleFrom(
//                                   backgroundColor: AppColors.gambianBlue,
//                                   foregroundColor: Colors.white,
//                                   minimumSize: const Size(64, 36),
//                                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                                 ),
//                                 child: const Text('Save'),
//                               ),
//                       ),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/professional_fees_api.dart';
import '../config/constants.dart';
import '../theme/app_colors.dart';

class ProfilePricingSection extends StatefulWidget {
  const ProfilePricingSection({super.key, required this.token});

  final String token;

  @override
  State<ProfilePricingSection> createState() => _ProfilePricingSectionState();
}

class _ProfilePricingSectionState extends State<ProfilePricingSection> {
  ProfessionalFeesResponse? _data;
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await fetchProfessionalFees(widget.token);
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      for (final i in r.items) {
        _controllers[i.productTypeId] = TextEditingController(text: i.feeAmount ?? '');
      }
      if (mounted) {
        setState(() {
          _data = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = null;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String productTypeId) async {
    final ctrl = _controllers[productTypeId];
    if (ctrl == null) return;
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) return;
    setState(() => _savingId = productTypeId);
    try {
      final res = await putProfessionalFee(widget.token, productTypeId, raw);
      final v = res['feeAmount'];
      if (v is String) ctrl.text = v;
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final data = _data;
    if (data == null || data.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Rates',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${data.items.length} rate${data.items.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.items.map((row) {
            final controller = _controllers[row.productTypeId] ??=
                TextEditingController(text: row.feeAmount ?? '');
            return _PricingCard(
              item: row,
              controller: controller,
              isSaving: _savingId == row.productTypeId,
              onSave: () => _save(row.productTypeId),
            );
          }),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final ProfessionalFeeItem item;
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSave;

  const _PricingCard({
    required this.item,
    required this.controller,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gambianBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.code,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gambianBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gambianBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                kCurrencyPrefix,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gambianBlue,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0.00',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gambianBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'per engagement',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}