import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/create_transaction_sheet.dart';
import '../widgets/transaction_list_tile.dart';
import 'personal_kyc_apply_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionListItem> _items = [];
  String? _loadErr;
  bool _loading = true;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await listTransactionsForParty(t, u.id);
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _loadErr = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadErr = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreate() {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) return;
    if (!u.personalKycApproved) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PersonalKycApplyScreen()),
      );
      return;
    }
    showCreateTransactionSheet(
      context: context,
      token: t,
      selfId: u.id,
      onCreated: (id) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailScreen(transactionId: id),
          ),
        );
        _load();
      },
    );
  }

  List<TransactionListItem> _filteredItems() {
    if (_activeTab == 1) {
      return _items
          .where((item) => item.workflow == 'PUBLIC_SHAREABLE')
          .toList();
    }
    if (_activeTab == 2) {
      return _items
          .where((item) => item.workflow == 'ESCROW_TWO_PARTY')
          .toList();
    }
    return _items;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final userId = auth.user?.id ?? '';

    final u = auth.user;
    final canCreate = u?.personalKycApproved == true;
    final kycPending = u?.personalKycStatus == 'PENDING';
    final publicCount = _items
        .where((x) => x.workflow == 'PUBLIC_SHAREABLE')
        .length;
    final escrowCount = _items
        .where((x) => x.workflow == 'ESCROW_TWO_PARTY')
        .length;
    final inEscrowCount = _items
        .where(
          (x) => {'FUNDED', 'IN_PROGRESS', 'INSPECTION'}.contains(x.status),
        )
        .length;
    final filtered = _filteredItems();
    final tabs = [
      _TransactionListTab('All', _items.length, Icons.layers_rounded),
      _TransactionListTab('Shareable', publicCount, Icons.link_rounded),
      _TransactionListTab('Escrow', escrowCount, Icons.shield_outlined),
    ];

    return RefreshIndicator(
      color: AppColors.primaryColorBlack,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderPanel(
            canCreate: canCreate,
            kycPending: kycPending,
            onCreate: _openCreate,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatPill(
                  label: 'Total',
                  value: _items.length,
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  label: 'Links',
                  value: publicCount,
                  icon: Icons.link_rounded,
                  tone: AppColors.primaryColorBlack,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  label: 'Escrow',
                  value: escrowCount,
                  icon: Icons.shield_outlined,
                  tone: AppColors.primaryColorBlack,
                ),
                // const SizedBox(width: 10),
                // _StatPill(
                //   label: 'Held',
                //   value: inEscrowCount,
                //   icon: Icons.lock_outline_rounded,
                //   tone: AppColors.gambianEarth,
                // ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // _TransactionTabRail(
          //   tabs: tabs,
          //   activeIndex: _activeTab,
          //   onChanged: (index) => setState(() => _activeTab = index),
          // ),
          const SizedBox(height: 16),
          if (_loadErr != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                _loadErr!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          if (_loading && filtered.isEmpty && _loadErr == null)
            const _TransactionsLoading()
          else if (filtered.isEmpty && _loadErr == null)
            _EmptyTransactions(activeTab: _activeTab)
          else
            ...List.generate(filtered.length, (i) {
              final row = filtered[i];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == filtered.length - 1 ? 0 : 12,
                ),
                child: TransactionListTileCard(
                  row: row,
                  selfUserId: userId,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TransactionDetailScreen(transactionId: row.id),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.canCreate,
    required this.kycPending,
    required this.onCreate,
  });

  final bool canCreate;
  final bool kycPending;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final label = canCreate
        ? 'Create transaction'
        : kycPending
        ? 'KYC pending review'
        : 'Apply KYC';
    final icon = canCreate
        ? Icons.add_rounded
        : kycPending
        ? Icons.hourglass_top_rounded
        : Icons.verified_user_outlined;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primaryColorBlack,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transactions',
                      style: displayHeading(context).copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryColorBlack,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(icon, size: 20),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

class _TransactionListTab {
  const _TransactionListTab(this.label, this.count, this.icon);

  final String label;
  final int count;
  final IconData icon;
}

class _TransactionTabRail extends StatelessWidget {
  const _TransactionTabRail({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<_TransactionListTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final active = index == activeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryColorBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: active ? Colors.white : Colors.grey.shade500,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tab.count}',
                      style: TextStyle(
                        color: active
                            ? Colors.white.withValues(alpha: 0.75)
                            : Colors.grey.shade500,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// class _StatPill extends StatelessWidget {
//   const _StatPill({
//     required this.label,
//     required this.value,
//     required this.icon,
//     this.tone,
//   });

//   final String label;
//   final int value;
//   final IconData icon;
//   final Color? tone;

//   @override
//   Widget build(BuildContext context) {
//     final color = tone ?? AppColors.primaryColorBlack;
//     return Container(
//       width: 124,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFE8EBF2)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             height: 75,
//             width: 100,
//             decoration: BoxDecoration(
//               color: color.withValues(alpha: 0.09),
//               borderRadius: BorderRadius.circular(11),
//             ),
//             child: Icon(icon, size: 18, color: color),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
//                 ),
//                 Text(
//                   '$value',
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w900,
//                     fontSize: 17,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.primaryColorBlack;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsLoading extends StatelessWidget {
  const _TransactionsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            width: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primaryColorBlack,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading transactions...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.activeTab});

  final int activeTab;

  @override
  Widget build(BuildContext context) {
    final message = activeTab == 1
        ? 'No shareable sales yet.'
        : activeTab == 2
        ? 'No two-party escrow rooms yet.'
        : 'No transactions yet.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primaryColorBlack,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../api/api_error.dart';
// import '../api/transactions_api.dart';
// import '../auth/auth_controller.dart';
// import '../models/transaction_models.dart';
// import '../theme/app_colors.dart';
// import '../widgets/create_transaction_sheet.dart';
// import '../widgets/transaction_list_tile.dart';
// import 'personal_kyc_apply_screen.dart';
// import 'transaction_detail_screen.dart';

// class TransactionsScreen extends StatefulWidget {
//   const TransactionsScreen({super.key});

//   @override
//   State<TransactionsScreen> createState() => _TransactionsScreenState();
// }

// class _TransactionsScreenState extends State<TransactionsScreen> {
//   List<TransactionListItem> _items = [];
//   String? _loadErr;
//   int _activeTab = 0;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _load());
//   }

//   Future<void> _load() async {
//     final auth = context.read<AuthController>();
//     final t = auth.token;
//     final u = auth.user;
//     if (t == null || u == null) return;
//     try {
//       final res = await listTransactionsForParty(t, u.id);
//       setState(() {
//         _items = res.items;
//         _loadErr = null;
//       });
//     } catch (e) {
//       setState(() => _loadErr = errorMessage(e));
//     }
//   }

//   void _openCreate() {
//     final auth = context.read<AuthController>();
//     final t = auth.token;
//     final u = auth.user;
//     if (t == null || u == null) return;
//     if (!u.personalKycApproved) {
//       Navigator.of(context).push(
//         MaterialPageRoute<void>(builder: (_) => const PersonalKycApplyScreen()),
//       );
//       return;
//     }
//     showCreateTransactionSheet(
//       context: context,
//       token: t,
//       selfId: u.id,
//       onCreated: (id) {
//         Navigator.of(context).push(
//           MaterialPageRoute<void>(
//             builder: (_) => TransactionDetailScreen(transactionId: id),
//           ),
//         );
//         _load();
//       },
//     );
//   }

//   List<TransactionListItem> _filteredItems() {
//     if (_activeTab == 1) return _items.where((i) => i.workflow == 'PUBLIC_SHAREABLE').toList();
//     if (_activeTab == 2) return _items.where((i) => i.workflow == 'ESCROW_TWO_PARTY').toList();
//     return _items;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthController>();
//     final userId = auth.user?.id ?? '';
//     final u = auth.user;
//     final canCreate = u?.personalKycApproved == true;
//     final kycPending = u?.personalKycStatus == 'PENDING';

//     final publicCount = _items.where((x) => x.workflow == 'PUBLIC_SHAREABLE').length;
//     final escrowCount = _items.where((x) => x.workflow == 'ESCROW_TWO_PARTY').length;
//     final activeCount = _items
//         .where((x) => {'FUNDED', 'IN_PROGRESS', 'INSPECTION'}.contains(x.status))
//         .length;
//     final filtered = _filteredItems();

//     return RefreshIndicator(
//       color: AppColors.primaryColorBlack,
//       onRefresh: _load,
//       child: ListView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: EdgeInsets.zero,
//         children: [
//           _TopBar(
//             canCreate: canCreate,
//             kycPending: kycPending,
//             onCreate: _openCreate,
//           ),
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _StatsRow(
//                   total: _items.length,
//                   links: publicCount,
//                   escrow: escrowCount,
//                   active: activeCount,
//                 ),
//                 const SizedBox(height: 20),
//                 _TabRow(
//                   activeIndex: _activeTab,
//                   counts: [_items.length, publicCount, escrowCount],
//                   onChanged: (i) => setState(() => _activeTab = i),
//                 ),
//                 const SizedBox(height: 16),
//                 if (_loadErr != null)
//                   _ErrorBox(message: _loadErr!),
//                 if (filtered.isEmpty && _loadErr == null)
//                   _EmptyState(tab: _activeTab)
//                 else
//                   ...List.generate(filtered.length, (i) {
//                     final row = filtered[i];
//                     return Padding(
//                       padding: EdgeInsets.only(bottom: i == filtered.length - 1 ? 24 : 12),
//                       child: TransactionListTileCard(
//                         row: row,
//                         selfUserId: userId,
//                         onTap: () => Navigator.of(context).push(
//                           MaterialPageRoute<void>(
//                             builder: (_) => TransactionDetailScreen(transactionId: row.id),
//                           ),
//                         ),
//                       ),
//                     );
//                   }),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Top bar ─────────────────────────────────────────────────────────────────

// class _TopBar extends StatelessWidget {
//   const _TopBar({
//     required this.canCreate,
//     required this.kycPending,
//     required this.onCreate,
//   });

//   final bool canCreate;
//   final bool kycPending;
//   final VoidCallback onCreate;

//   @override
//   Widget build(BuildContext context) {
//     final buttonLabel = canCreate
//         ? 'New Transaction'
//         : kycPending
//             ? 'KYC Pending'
//             : 'Verify Identity';

//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
//       decoration: const BoxDecoration(
//         color: AppColors.primaryColorBlack,
//         borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Transactions',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 28,
//                 fontWeight: FontWeight.w900,
//                 letterSpacing: -0.5,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               'Manage your sales and escrow deals',
//               style: TextStyle(
//                 color: Colors.white.withValues(alpha: 0.7),
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 18),
//             SizedBox(
//               width: double.infinity,
//               child: FilledButton.icon(
//                 onPressed: onCreate,
//                 style: FilledButton.styleFrom(
//                   backgroundColor: Colors.white,
//                   foregroundColor: AppColors.primaryColorBlack,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   elevation: 0,
//                 ),
//                 icon: Icon(
//                   canCreate ? Icons.add_rounded : Icons.verified_user_outlined,
//                   size: 20,
//                 ),
//                 label: Text(
//                   buttonLabel,
//                   style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─── Stats row ───────────────────────────────────────────────────────────────

// class _StatsRow extends StatelessWidget {
//   const _StatsRow({
//     required this.total,
//     required this.links,
//     required this.escrow,
//     required this.active,
//   });

//   final int total, links, escrow, active;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         _StatCard(label: 'All', value: total, icon: Icons.receipt_long_rounded),
//         const SizedBox(width: 10),
//         _StatCard(label: 'Links', value: links, icon: Icons.link_rounded, accent: AppColors.primaryColorBlack),
//         const SizedBox(width: 10),
//         _StatCard(label: 'Escrow', value: escrow, icon: Icons.shield_outlined, accent: AppColors.gambianEarth),
//         const SizedBox(width: 10),
//         _StatCard(label: 'Active', value: active, icon: Icons.bolt_rounded, accent: const Color(0xFF16A34A)),
//       ],
//     );
//   }
// }

// class _StatCard extends StatelessWidget {
//   const _StatCard({
//     required this.label,
//     required this.value,
//     required this.icon,
//     this.accent,
//   });

//   final String label;
//   final int value;
//   final IconData icon;
//   final Color? accent;

//   @override
//   Widget build(BuildContext context) {
//     final color = accent ?? Colors.grey.shade700;
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: const Color(0xFFEEF0F6)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Icon(icon, size: 16, color: color),
//             const SizedBox(height: 6),
//             Text(
//               '$value',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w900,
//                 color: color,
//                 letterSpacing: -0.5,
//               ),
//             ),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey.shade500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─── Tab row ─────────────────────────────────────────────────────────────────

// class _TabRow extends StatelessWidget {
//   const _TabRow({
//     required this.activeIndex,
//     required this.counts,
//     required this.onChanged,
//   });

//   final int activeIndex;
//   final List<int> counts;
//   final ValueChanged<int> onChanged;

//   static const _labels = ['All', 'Links', 'Escrow'];
//   static const _icons = [
//     Icons.layers_rounded,
//     Icons.link_rounded,
//     Icons.shield_outlined,
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF1F5FB),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Row(
//         children: List.generate(3, (i) {
//           final active = i == activeIndex;
//           return Expanded(
//             child: GestureDetector(
//               onTap: () => onChanged(i),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 curve: Curves.easeOut,
//                 padding: const EdgeInsets.symmetric(vertical: 10),
//                 decoration: BoxDecoration(
//                   color: active ? Colors.white : Colors.transparent,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: active
//                       ? [
//                           BoxShadow(
//                             color: Colors.black.withValues(alpha: 0.07),
//                             blurRadius: 8,
//                             offset: const Offset(0, 2),
//                           ),
//                         ]
//                       : null,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       _icons[i],
//                       size: 15,
//                       color: active ? AppColors.primaryColorBlack : Colors.grey.shade500,
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       _labels[i],
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w800,
//                         color: active ? AppColors.primaryColorBlack : Colors.grey.shade600,
//                       ),
//                     ),
//                     if (counts[i] > 0) ...[
//                       const SizedBox(width: 5),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
//                         decoration: BoxDecoration(
//                           color: active
//                               ? AppColors.primaryColorBlack.withValues(alpha: 0.1)
//                               : Colors.grey.shade200,
//                           borderRadius: BorderRadius.circular(999),
//                         ),
//                         child: Text(
//                           '${counts[i]}',
//                           style: TextStyle(
//                             fontSize: 10,
//                             fontWeight: FontWeight.w900,
//                             color: active ? AppColors.primaryColorBlack : Colors.grey.shade600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }
// }

// // ─── Empty state ─────────────────────────────────────────────────────────────

// class _EmptyState extends StatelessWidget {
//   const _EmptyState({required this.tab});
//   final int tab;

//   @override
//   Widget build(BuildContext context) {
//     final message = tab == 1
//         ? 'No shareable sale links yet.'
//         : tab == 2
//             ? 'No escrow deals yet.'
//             : 'No transactions yet.';

//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: 52,
//             height: 52,
//             decoration: BoxDecoration(
//               color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryColorBlack),
//           ),
//           const SizedBox(height: 14),
//           Text(
//             message,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Error box ───────────────────────────────────────────────────────────────

// class _ErrorBox extends StatelessWidget {
//   const _ErrorBox({required this.message});
//   final String message;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.red.shade50,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.red.shade100),
//       ),
//       child: Text(message, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
//     );
//   }
// }
