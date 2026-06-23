import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_background.dart';
import '../widgets/transaction_notification_card.dart';
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
    _sseSub = transactionNotificationEvents(t, u.id).listen((_) => _load());
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

  Future<void> _openTransaction(String notifId, String txId, bool isNew) async {
    final token = context.read<AuthController>().token;
    if (token != null && isNew) {
      await markTransactionNotificationRead(token, notifId);
      await _load();
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionDetailScreen(transactionId: txId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.pageBackground),
            child: SizedBox.expand(),
          ),
          const PatternBackground(opacity: 0.08),
          SafeArea(
            top: false,
            child: RefreshIndicator(
              color: AppColors.primaryColorBlack,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Text(
                        'Notifications',
                        style: displayHeading(context).copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                  if (_isLoading && _items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _LoadingState(),
                    )
                  else if (_items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final n = _items[idx];
                          final isNew = n.readAt == null;
                          return TransactionNotificationCard(
                            item: n,
                            isProcessing: _processingId == n.id,
                            onReview: () => _openTransaction(n.id, n.transactionId, isNew),
                            onAccept: n.status == 'AWAITING_ACCEPTANCE'
                                ? () => _handleAccept(n.id, n.transactionId)
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryColorBlack),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade50, Colors.grey.shade50.withValues(alpha: 0.5)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryColorBlack.withValues(alpha: 0.1),
                      AppColors.primaryColorBlack.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.notifications_none_outlined,
                  size: 40,
                  color: AppColors.primaryColorBlack.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'All caught up!',
                style: displayHeading(context).copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No notifications at the moment. PayNexa transaction updates will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
