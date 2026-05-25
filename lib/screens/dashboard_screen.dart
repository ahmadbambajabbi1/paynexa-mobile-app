import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/create_transaction_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/transaction_list_tile.dart';
import 'transaction_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<TransactionListItem> _items = [];
  String? _loadErr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) return;
    try {
      final res = await listTransactionsForParty(t, u.id);
      setState(() {
        _items = res.items;
        _loadErr = null;
      });
    } catch (e) {
      setState(() => _loadErr = errorMessage(e));
    }
  }

  int _countActive() {
    const a = {
      'AWAITING_ACCEPTANCE',
      'AWAITING_FUNDING',
      'FUNDED',
      'IN_PROGRESS',
      'INSPECTION',
    };
    return _items.where((i) => a.contains(i.status)).length;
  }

  int _countDone() {
    const d = {'COMPLETED', 'CLOSED'};
    return _items.where((i) => d.contains(i.status)).length;
  }

  void _openCreate() {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) return;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final userId = auth.user?.id ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Text('My escrow dashboard', style: displayHeading(context).copyWith(fontSize: 28)),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cross = w >= 900 ? 4 : (w >= 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cross == 1 ? 2.2 : 1.3,
                children: [
                  _statCard(
                    icon: Icons.list_alt,
                    iconColor: AppColors.gambianBlue,
                    bg: Colors.blue.shade50,
                    label: 'Transactions',
                    value: '${_items.length}',
                  ),
                  _statCard(
                    icon: Icons.schedule,
                    iconColor: Colors.orange.shade800,
                    bg: Colors.yellow.shade50,
                    label: 'In progress',
                    value: '${_countActive()}',
                  ),
                  _statCard(
                    icon: Icons.done_all,
                    iconColor: AppColors.gambianGreen,
                    bg: Colors.green.shade50,
                    label: 'Completed / closed',
                    value: '${_countDone()}',
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openCreate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gambianBlue.withOpacity(0.4)),
                          color: Colors.white,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: 36, color: AppColors.gambianBlue),
                            const SizedBox(height: 8),
                            const Text(
                              'New transaction',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.gambianBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Recent transactions', style: displayHeading(context).copyWith(fontSize: 18)),
              const Spacer(),
              TextButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadErr != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_loadErr!, style: TextStyle(color: Colors.red.shade800)),
                  ),
                if (_items.isEmpty && _loadErr == null)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No transactions yet. Create one to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ...List.generate(_items.length, (i) {
                  final row = _items[i];
                  return Column(
                    children: [
                      if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
                      TransactionListTileCard(
                        row: row,
                        selfUserId: userId,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TransactionDetailScreen(transactionId: row.id),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
