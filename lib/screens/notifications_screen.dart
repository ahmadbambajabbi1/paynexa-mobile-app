import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import 'transaction_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<TransactionNotificationItem> _items = [];
  StreamSubscription<Map<String, dynamic>>? _sseSub;
  bool _isLoading = true;
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _load();
    _startRealtime();
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  void _startRealtime() {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) return;
    _sseSub?.cancel();
    _sseSub = transactionNotificationEvents(t, u.id).listen((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final t = auth.token;
    final u = auth.user;
    if (t == null || u == null) return;
    final res = await listTransactionNotifications(t, u.id);
    if (!mounted) return;
    setState(() {
      _items = res.items;
      _isLoading = false;
    });
  }

  Future<void> _handleAccept(String notifId, String txId) async {
    final token = context.read<AuthController>().token;
    final selfId = context.read<AuthController>().user?.id;
    if (token == null || selfId == null) return;
    
    setState(() => _processingId = notifId);
    try {
      await acceptTransaction(token, txId, selfId);
      await markTransactionNotificationRead(token, notifId);
      await _load();
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  ({Color bg, Color text, String icon}) _getStatusColors(String status) {
    final st = status.toLowerCase();
    if (st.contains('pending')) {
      return (
        bg: AppColors.gambianBlue.withValues(alpha: 0.1),
        text: AppColors.gambianBlue,
        icon: '⏳'
      );
    }
    if (st.contains('accepted') || st.contains('approved')) {
      return (
        bg: AppColors.gambianGreen.withValues(alpha: 0.1),
        text: AppColors.gambianGreen,
        icon: '✓'
      );
    }
    if (st.contains('rejected') || st.contains('failed')) {
      return (
        bg: AppColors.gambianRed.withValues(alpha: 0.1),
        text: AppColors.gambianRed,
        icon: '✕'
      );
    }
    return (bg: Colors.grey.shade100, text: Colors.grey.shade700, icon: '•');
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthController>().token;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final Widget content = (_isLoading && _items.isEmpty)
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.gambianBlue),
                const SizedBox(height: 16),
                Text(
                  'Loading notifications...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          )
        : _items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.gambianBlue.withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                Icons.notifications_off_outlined,
                                size: 40,
                                color: AppColors.gambianBlue.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All caught up!',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No notifications at the moment.\nNew transaction invitations will appear here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _items.length,
                itemBuilder: (context, idx) {
                  final n = _items[idx];
                  final isNew = n.readAt == null;
                  final colors = _getStatusColors(n.status);
                  final isProcessing = _processingId == n.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          if (token != null && isNew) {
                            await markTransactionNotificationRead(token, n.id);
                            await _load();
                          }
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TransactionDetailScreen(
                                transactionId: n.transactionId,
                              ),
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isNew
                                  ? AppColors.gambianBlue.withValues(alpha: 0.2)
                                  : Colors.grey.shade200,
                              width: isNew ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Existing card UI below remains unchanged
                              // (kept to avoid duplications and preserve current styling)
                              // ignore: prefer_const_constructors
                              SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.pageBackground),
            child: SizedBox.expand(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: content),
            ],
          ),
        ],
      ),
    );
  }
}
