import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_error.dart';
import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../models/me_user.dart';
import '../utils/invite_participant_message.dart';
import '../utils/parse_terms.dart';
import '../utils/transaction_room_title.dart';
import '../utils/transaction_ui.dart';
import '../widgets/glass_card.dart';
import '../widgets/transaction_payment_sheet.dart';
import '../widgets/transaction_room_product_section.dart';

class _TransactionDetailTab {
  const _TransactionDetailTab(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionRoom? _room;
  String? _err;
  bool _busy = false;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _err = null);
    try {
      final r = await getTransactionRoom(token, widget.transactionId);
      setState(() => _room = r);
    } catch (e) {
      setState(() {
        _err = errorMessage(e);
        _room = null;
      });
    }
  }

  Future<void> _accept() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final uid = auth.user?.id;
    final room = _room;
    if (token == null || uid == null || room == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await acceptTransaction(token, room.transaction.id, uid);
      await _load();
    } catch (e) {
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transition(String next) async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final uid = auth.user?.id;
    final room = _room;
    if (token == null || uid == null || room == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await updateTransactionState(token, room.transaction.id, uid, next);
      await _load();
    } catch (e) {
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final tx = _room?.transaction;

    final room = _room;
    final title = room != null && tx != null
        ? transactionRoomHeading(room)
        : '';
    final progressPct = tx != null ? statusApproxProgress(tx.status) : 0.0;
    final selfRole = tx != null && user != null
        ? (user.id == tx.buyerId
              ? 'buyer'
              : user.id == tx.sellerId
              ? 'seller'
              : 'other')
        : 'other';
    final canAccept =
        tx != null &&
        selfRole == 'buyer' &&
        tx.status == 'AWAITING_ACCEPTANCE' &&
        user != null &&
        !tx.acceptedPartyIds.contains(user.id);
    final nextStates = tx != null
        ? _visibleTransitions(
            kStatusTransitions[tx.status] ?? <String>[],
            selfRole,
          )
        : <String>[];
    final canPayFromWallet =
        tx != null &&
        selfRole == 'buyer' &&
        tx.shareToken == null &&
        tx.status == 'AWAITING_FUNDING';
    final isPublicShareable = tx?.workflow == 'PUBLIC_SHAREABLE';
    final tabs = tx != null
        ? _detailTabs(isPublicShareable, selfRole)
        : const <_TransactionDetailTab>[];
    final activeIndex = tabs.isEmpty
        ? 0
        : _activeTab.clamp(0, tabs.length - 1).toInt();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.pageBackground),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to transactions'),
                    ),
                  ),
                  if (_err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _err!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  if (tx == null && _err == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (tx != null) ...[
                    _transactionHero(
                      tx,
                      title,
                      progressPct,
                      selfRole,
                      isPublicShareable,
                    ),
                    const SizedBox(height: 14),
                    _tabBar(tabs, activeIndex),
                    const SizedBox(height: 14),
                    _tabBody(
                      tabs[activeIndex].id,
                      user?.id,
                      tx,
                      title,
                      progressPct,
                      canAccept,
                      nextStates,
                      isPublicShareable,
                      canPayFromWallet,
                      selfRole,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TransactionDetailTab> _detailTabs(
    bool isPublicShareable,
    String selfRole,
  ) {
    if (isPublicShareable) {
      return [
        const _TransactionDetailTab(
          'overview',
          'Overview',
          Icons.dashboard_rounded,
        ),
        const _TransactionDetailTab(
          'details',
          'Sale',
          Icons.receipt_long_rounded,
        ),
        const _TransactionDetailTab(
          'parties',
          'Parties',
          Icons.people_alt_outlined,
        ),
        if (selfRole == 'seller')
          const _TransactionDetailTab(
            'analytics',
            'Analytics',
            Icons.query_stats_rounded,
          ),
        const _TransactionDetailTab(
          'timeline',
          'Timeline',
          Icons.history_rounded,
        ),
      ];
    }
    return const [
      _TransactionDetailTab('overview', 'Overview', Icons.dashboard_rounded),
      _TransactionDetailTab('details', 'Product', Icons.inventory_2_outlined),
      _TransactionDetailTab('parties', 'Parties', Icons.people_alt_outlined),
      _TransactionDetailTab('team', 'Team', Icons.person_add_alt_1_rounded),
      _TransactionDetailTab('timeline', 'Timeline', Icons.history_rounded),
    ];
  }

  Widget _tabBody(
    String tabId,
    String? userId,
    TxEntity tx,
    String title,
    double progressPct,
    bool canAccept,
    List<String> nextStates,
    bool isPublicShareable,
    bool canPayFromWallet,
    String selfRole,
  ) {
    switch (tabId) {
      case 'overview':
        return _overviewTab(
          tx,
          title,
          progressPct,
          canAccept,
          nextStates,
          isPublicShareable,
          canPayFromWallet,
          selfRole,
        );
      case 'details':
        return isPublicShareable ? _publicSaleTab(tx) : _productTab(tx);
      case 'parties':
        return _partiesTab(userId, tx);
      case 'analytics':
        return _publicAnalyticsTab();
      case 'team':
        return _teamTab(tx, userId);
      case 'timeline':
        return _timelineTab(userId);
      default:
        return _overviewTab(
          tx,
          title,
          progressPct,
          canAccept,
          nextStates,
          isPublicShareable,
          canPayFromWallet,
          selfRole,
        );
    }
  }

  Future<void> _payFromWallet(TxEntity tx) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    final amount = double.tryParse(tx.amount) ?? 0;
    if (amount <= 0) return;

    final paid = await showTransactionPaymentSheet(
      context: context,
      transactionId: tx.id,
      amount: amount,
    );
    if (paid == null || !mounted) return;

    if (paid != tx.id) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailScreen(transactionId: paid),
        ),
      );
      return;
    }
    await _load();
  }

  Widget _tabBar(List<_TransactionDetailTab> tabs, int activeIndex) {
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final active = activeIndex == index;
            return Padding(
              padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 6),
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 104,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.gambianBlue : Colors.transparent,
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
                      const SizedBox(height: 5),
                      Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _transactionHero(
    TxEntity tx,
    String title,
    double progressPct,
    String selfRole,
    bool isPublicShareable,
  ) {
    const workflowColor = AppColors.gambianBlue;
    final workflowBg = Colors.blue.shade50;
    final roleLabel = selfRole == 'buyer'
        ? 'Buyer'
        : selfRole == 'seller'
        ? 'Seller'
        : 'Collaborator';

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusBadge(tx.status),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: workflowBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isPublicShareable ? 'Shareable sale' : 'Two-party escrow',
                    style: TextStyle(
                      color: workflowColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '#${tx.id.substring(0, tx.id.length >= 8 ? 8 : tx.id.length)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: displayHeading(context).copyWith(fontSize: 25)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    'Amount',
                    '$kCurrencyPrefix${tx.amount}',
                    strong: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _miniInfo('Role', roleLabel)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (progressPct / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                color: workflowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: strong ? 18 : 14,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: strong ? AppColors.gambianBlue : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _visibleTransitions(List<String> transitions, String role) {
    return transitions.where((next) {
      if (role == 'buyer') {
        return {'COMPLETED', 'DISPUTED'}.contains(next);
      }
      if (role == 'seller') {
        return {'IN_PROGRESS', 'INSPECTION', 'DISPUTED'}.contains(next);
      }
      return false;
    }).toList();
  }

  Widget _overviewTab(
    TxEntity tx,
    String title,
    double progressPct,
    bool canAccept,
    List<String> nextStates,
    bool isPublicShareable,
    bool canPayFromWallet,
    String selfRole,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: displayHeading(context).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statusBadge(tx.status),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isPublicShareable
                            ? 'Shareable sale'
                            : 'Two-party escrow',
                        style: const TextStyle(
                          color: AppColors.gambianBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _miniInfo(
                        'Amount',
                        '$kCurrencyPrefix${tx.amount}',
                        strong: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniInfo('Status', formatStatus(tx.status)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _progressBar(progressPct),
                if (canAccept) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gambianBlue,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Accept transaction'),
                  ),
                ],
                if (canPayFromWallet) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _payFromWallet(tx),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gambianBlue,
                    ),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Pay from wallet'),
                  ),
                ],
                if (nextStates.where((s) => s != 'CLOSED').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: nextStates
                        .where((s) => s != 'CLOSED')
                        .map(
                          (s) => OutlinedButton(
                            onPressed: _busy ? null : () => _transition(s),
                            child: Text(formatStatus(s)),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (canBuyerCloseTransaction(
                  selfRole,
                  buyerId: tx.buyerId,
                  shareToken: tx.shareToken,
                  status: tx.status,
                )) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _transition('CLOSED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade800,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: const Text('Close transaction'),
                  ),
                ],
                const SizedBox(height: 16),
                _dealSummary(tx),
                if (isPublicShareable && tx.shareToken != null)
                  _shareLinkCard(tx),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineTab(String? userId) {
    final events = _room?.timeline ?? const <TimelineEvent>[];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: displayHeading(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No activity yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...List.generate(events.length, (index) {
              final ev = events[index];
              final actorLabel = userId != null && _room != null
                  ? timelineActorLabel(ev.actorId, _room!, userId)
                  : ev.actorId;
              final isLast = index == events.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.circle,
                          size: 7,
                          color: AppColors.gambianBlue,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 46,
                          color: Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.action,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ev.at,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (ev.detail.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                ev.detail,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Actor: $actorLabel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _partiesTab(String? userId, TxEntity tx) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buyer and seller',
            style: displayHeading(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          _partyTile('Buyer', userId == tx.buyerId, _room?.parties?.buyer),
          const SizedBox(height: 8),
          _partyTile('Seller', userId == tx.sellerId, _room?.parties?.seller),
        ],
      ),
    );
  }

  Widget _productTab(TxEntity tx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_room?.product != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TransactionRoomProductSection(product: _room!.product!),
          ),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue.shade100),
                  ),
                ),
                child: Text(
                  'Deal summary',
                  style: displayHeading(context).copyWith(fontSize: 18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _dealSummary(tx),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _publicSaleTab(TxEntity tx) {
    final terms = _parsePublicTerms(tx.terms);
    final quantity = tx.quantity ?? 1;
    final unitPrice = tx.unitPrice ?? tx.amount;
    final itemDescription = terms['itemDescription'] as String?;
    final sellerNote = terms['sellerNote'] as String?;
    final deliveryNeeded = terms['deliveryNeeded'] == true;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Text(
              'Sale details',
              style: displayHeading(context).copyWith(fontSize: 18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _miniInfo('Quantity', '$quantity')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniInfo(
                        'Unit price',
                        '$kCurrencyPrefix$unitPrice',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _summaryRow('Total', '$kCurrencyPrefix${tx.amount}'),
                if (itemDescription != null && itemDescription.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      itemDescription,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                if (sellerNote != null && sellerNote.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gambianSand.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gambianSand),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller note',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.gambianEarth,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sellerNote,
                          style: const TextStyle(
                            color: AppColors.gambianEarth,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _summaryRow(
                  'Fulfillment',
                  deliveryNeeded ? 'Delivery tracked' : 'Payment only',
                ),
                if (tx.shareToken != null || (tx.sharePath ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _shareLinkCard(tx),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicAnalyticsTab() {
    final analytics = _room?.publicAnalytics;
    final totalViews = analytics?.totalViews ?? 0;
    final uniqueViewers = analytics?.uniqueViewers ?? 0;
    final paidCount = analytics?.paidCount ?? 0;
    final conversionRate = analytics?.conversionRate ?? '0.0';
    final viewers =
        analytics?.recentViewers ?? const <PublicTransactionViewer>[];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link analytics',
            style: displayHeading(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniInfo('Views', '$totalViews')),
              const SizedBox(width: 10),
              Expanded(child: _miniInfo('Unique', '$uniqueViewers')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniInfo('Paid', '$paidCount')),
              const SizedBox(width: 10),
              Expanded(child: _miniInfo('Conversion', '$conversionRate%')),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recent viewers',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 10),
          if (viewers.isEmpty)
            Text(
              'No link views yet.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...viewers.map(
              (viewer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _summaryRow(
                  viewer.label,
                  viewer.convertedAt == null
                      ? 'Viewed ${viewer.viewedAt}'
                      : 'Paid ${viewer.convertedAt}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamTab(TxEntity tx, String? userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _participantRoleTab(role: 'AGENT', tx: tx, userId: userId),
        const SizedBox(height: 14),
        _participantRoleTab(role: 'LAWYER', tx: tx, userId: userId),
      ],
    );
  }

  Map<String, Object?> _parsePublicTerms(String terms) {
    try {
      final raw = jsonDecode(terms);
      if (raw is Map) {
        return {
          'itemDescription': raw['itemDescription'] is String
              ? (raw['itemDescription'] as String).trim()
              : null,
          'sellerNote': raw['sellerNote'] is String
              ? (raw['sellerNote'] as String).trim()
              : null,
          'deliveryNeeded': raw['deliveryNeeded'] == true,
        };
      }
    } catch (_) {}
    return {
      'itemDescription': null,
      'sellerNote': null,
      'deliveryNeeded': false,
    };
  }

  String _inviterLabel(MeUser u) {
    for (final s in [u.displayName, u.fullName, u.email, u.phone]) {
      final t = s?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return 'Transaction participant';
  }

  Widget _participantRoleTab({
    required String role,
    required TxEntity tx,
    required String? userId,
  }) {
    final isLawyer = role == 'LAWYER';
    final pt = _room?.product?.productType;
    final pricingEnabled = isLawyer
        ? (pt?.lawyerPricingEnabled ?? false)
        : (pt?.agentPricingEnabled ?? false);
    final roleWord = isLawyer ? 'lawyer' : 'agent';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLawyer ? 'Lawyers' : 'Agents',
            style: displayHeading(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          _sideProfessionalBlock(
            title: "Buyer's $roleWord",
            profile: isLawyer
                ? _room?.parties?.buyerLawyer
                : _room?.parties?.buyerAgent,
            inviteStatus: isLawyer
                ? tx.buyerLawyerInviteStatus
                : tx.buyerAgentInviteStatus,
            invitedId: isLawyer ? tx.buyerLawyerId : tx.buyerAgentId,
            partySide: 'buyer',
            role: role,
            userId: userId,
            tx: tx,
            pricingEnabled: pricingEnabled,
          ),
          const SizedBox(height: 20),
          _sideProfessionalBlock(
            title: "Seller's $roleWord",
            profile: isLawyer
                ? _room?.parties?.sellerLawyer
                : _room?.parties?.sellerAgent,
            inviteStatus: isLawyer
                ? tx.sellerLawyerInviteStatus
                : tx.sellerAgentInviteStatus,
            invitedId: isLawyer ? tx.sellerLawyerId : tx.sellerAgentId,
            partySide: 'seller',
            role: role,
            userId: userId,
            tx: tx,
            pricingEnabled: pricingEnabled,
          ),
        ],
      ),
    );
  }

  Widget _sideProfessionalBlock({
    required String title,
    required PartyProfile? profile,
    required String inviteStatus,
    required String? invitedId,
    required String partySide,
    required String role,
    required String? userId,
    required TxEntity tx,
    required bool pricingEnabled,
  }) {
    final canInvite =
        pricingEnabled &&
        userId != null &&
        ((partySide == 'buyer' && userId == tx.buyerId) ||
            (partySide == 'seller' && userId == tx.sellerId));
    final canAcceptInvite =
        userId != null &&
        invitedId != null &&
        userId == invitedId &&
        inviteStatus == 'PENDING';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (profile == null)
          Text(
            'No one invited yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          )
        else
          _partyTile(title, userId == invitedId, profile),
        Text(
          'Status: $inviteStatus',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        if (canInvite) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || !pricingEnabled
                ? null
                : () => _openInviteParticipant(role, partySide),
            icon: const Icon(Icons.person_add_alt),
            label: Text('Invite ${role == 'LAWYER' ? 'lawyer' : 'agent'}'),
          ),
        ],
        if (canAcceptInvite) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _acceptParticipant(role, partySide),
            child: const Text('Accept invite'),
          ),
        ],
      ],
    );
  }

  Future<void> _acceptParticipant(String role, String partySide) async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final uid = auth.user?.id;
    final txId = _room?.transaction.id;
    if (token == null || uid == null || txId == null) return;
    setState(() => _busy = true);
    try {
      await acceptTransactionParticipantInvite(
        token,
        txId,
        actorId: uid,
        role: role,
        partySide: partySide,
      );
      await _load();
    } catch (e) {
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openInviteParticipant(String role, String partySide) async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final uid = auth.user?.id;
    final u = auth.user;
    final room = _room;
    final txId = room?.transaction.id;
    final tx = room?.transaction;
    if (token == null ||
        uid == null ||
        txId == null ||
        tx == null ||
        u == null) {
      return;
    }

    final selected = await showModalBottomSheet<ProfessionalSearchItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteParticipantSheet(
        token: token,
        txId: txId,
        role: role,
        partySide: partySide,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.invited) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That professional is already invited for this slot.'),
        ),
      );
      return;
    }

    final initial = buildParticipantInviteMessageTemplate(
      inviterLabel: _inviterLabel(u),
      partySide: partySide,
      role: role,
      productTitle: tx.productTitle,
      amount: tx.amount,
      transactionId: tx.id,
    );
    final ctrl = TextEditingController(text: initial);
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invite ${role == 'LAWYER' ? 'lawyer' : 'agent'}'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Message to send',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (message == null || message.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await inviteTransactionParticipant(
        token,
        txId,
        actorId: uid,
        participantUserId: selected.id,
        role: role,
        partySide: partySide,
        message: message,
      );
      await _load();
    } catch (e) {
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _statusBadge(String status) {
    final done = status == 'COMPLETED' || status == 'CLOSED';
    final disputed = status == 'DISPUTED';
    Color bg = AppColors.gambianSand.withValues(alpha: 0.65);
    Color fg = AppColors.gambianEarth;
    if (done ||
        status == 'AWAITING_FUNDING' ||
        status == 'FUNDED' ||
        status == 'IN_PROGRESS' ||
        status == 'INSPECTION') {
      bg = Colors.blue.shade50;
      fg = AppColors.gambianBlue;
    } else if (disputed) {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        formatStatus(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _progressBar(double pct) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.gambianBlue,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) {
            final step = (i + 1) * 25;
            final done = pct >= step;
            return Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: done
                        ? AppColors.gambianBlue
                        : Colors.grey.shade300,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ['Created', 'Funded', 'Delivered', 'Completed'][i],
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _partyTile(String label, bool isYou, PartyProfile? profile) {
    final name = profile?.displayName?.trim();
    final email = profile?.email?.trim();
    final phone = profile?.phone?.trim();
    final isBuyerTone = label.toLowerCase().contains('buyer');
    final bg = isBuyerTone
        ? Colors.blue.shade50
        : AppColors.gambianSand.withValues(alpha: 0.45);
    final border = isBuyerTone ? Colors.blue.shade100 : AppColors.gambianSand;
    final accent = isBuyerTone ? AppColors.gambianBlue : AppColors.gambianEarth;
    final hasContact =
        name?.isNotEmpty == true ||
        email?.isNotEmpty == true ||
        phone?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: accent,
            child: Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                    if (isYou)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.gambianBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (profile != null && hasContact) ...[
                  if (name?.isNotEmpty == true)
                    Text(
                      name!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  if (email?.isNotEmpty == true)
                    SelectableText(
                      email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  if (phone?.isNotEmpty == true)
                    SelectableText(
                      phone!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                ] else
                  Text(
                    profile == null
                        ? 'Profile unavailable'
                        : 'No contact details on file',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareLinkCard(TxEntity tx) {
    final shareUrl = tx.shareToken != null
        ? '$kShareBaseUrl/pay/${tx.shareToken}'
        : (tx.sharePath != null
            ? (tx.sharePath!.startsWith('http')
                ? tx.sharePath!
                : '$kShareBaseUrl${tx.sharePath}')
            : '');

    if (shareUrl.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gambianBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gambianBlue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link_rounded, color: AppColors.gambianBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Shareable Payment Link',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.gambianBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Send this link to the buyer via WhatsApp, Facebook, Instagram, or other apps so they can fund the escrow securely.',
            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    Share.share(
                      shareUrl,
                      subject: 'Escrow Payment Link',
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gambianBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Share Link',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gambianBlue,
                    side: const BorderSide(color: AppColors.gambianBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copy',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dealSummary(TxEntity tx) {
    final deal = parseTermsDeal(tx.terms);
    final f = tx.fundedBy.toUpperCase();
    final fundingLabel = f.contains('COUNTERPARTY')
        ? 'Buyer payment'
        : f.contains('ME')
        ? 'Seller payment'
        : tx.fundedBy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryRow('Amount', '$kCurrencyPrefix${tx.amount}'),
        const SizedBox(height: 10),
        _summaryRow('Funding', fundingLabel),
        if (deal?['productTitle'] != null &&
            deal!['productTitle']!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _summaryRow('Product title', deal['productTitle']!),
        ],
      ],
    );
  }

  Widget _summaryRow(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
        color: Colors.blue.shade50.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.gambianBlue,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            v,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteParticipantSheet extends StatefulWidget {
  const _InviteParticipantSheet({
    required this.token,
    required this.txId,
    required this.role,
    required this.partySide,
  });

  final String token;
  final String txId;
  final String role;
  final String partySide;

  @override
  State<_InviteParticipantSheet> createState() =>
      _InviteParticipantSheetState();
}

class _InviteParticipantSheetState extends State<_InviteParticipantSheet> {
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  List<ProfessionalSearchItem> _items = [];
  String? _disabledReason;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    setState(() => _busy = true);
    try {
      final res = await searchTransactionParticipants(
        widget.token,
        widget.txId,
        widget.role,
        q,
        partySide: widget.partySide,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _disabledReason = res.disabledReason;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _queryCtrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                labelText:
                    'Search ${widget.role.toLowerCase()} (${widget.partySide})',
                hintText: 'Name, email, phone, or id',
              ),
            ),
            const SizedBox(height: 12),
            if (_disabledReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _disabledReason!,
                  style: TextStyle(fontSize: 12, color: AppColors.gambianEarth),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return ListTile(
                      title: Text(item.displayName ?? item.id),
                      subtitle: Text(
                        [
                          if ((item.email ?? '').isNotEmpty) item.email!,
                          if ((item.phone ?? '').isNotEmpty) item.phone!,
                        ].join(' · '),
                      ),
                      trailing: item.invited ? const Text('Invited') : null,
                      onTap: item.invited
                          ? null
                          : () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:share_plus/share_plus.dart';

// import '../api/api_error.dart';
// import '../api/transactions_api.dart';
// import '../auth/auth_controller.dart';
// import '../models/transaction_models.dart';
// import '../theme/app_colors.dart';
// import '../theme/app_theme.dart';
// import '../config/constants.dart';
// import '../models/me_user.dart';
// import '../utils/invite_participant_message.dart';
// import '../utils/parse_terms.dart';
// import '../utils/transaction_room_title.dart';
// import '../utils/transaction_ui.dart';
// import '../widgets/glass_card.dart';
// import '../widgets/transaction_payment_sheet.dart';
// import '../widgets/transaction_room_product_section.dart';

// // ─── Tab model ────────────────────────────────────────────────────────────────

// class _Tab {
//   const _Tab(this.id, this.label, this.icon);
//   final String id;
//   final String label;
//   final IconData icon;
// }

// // ─── Screen ───────────────────────────────────────────────────────────────────

// class TransactionDetailScreen extends StatefulWidget {
//   const TransactionDetailScreen({super.key, required this.transactionId});
//   final String transactionId;

//   @override
//   State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
// }

// class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
//   TransactionRoom? _room;
//   String? _err;
//   bool _busy = false;
//   int _activeTab = 0;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _load());
//   }

//   Future<void> _load() async {
//     final token = context.read<AuthController>().token;
//     if (token == null) return;
//     setState(() => _err = null);
//     try {
//       final r = await getTransactionRoom(token, widget.transactionId);
//       setState(() => _room = r);
//     } catch (e) {
//       setState(() { _err = errorMessage(e); _room = null; });
//     }
//   }

//   Future<void> _accept() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     final uid = auth.user?.id;
//     final room = _room;
//     if (token == null || uid == null || room == null) return;
//     setState(() { _busy = true; _err = null; });
//     try {
//       await acceptTransaction(token, room.transaction.id, uid);
//       await _load();
//     } catch (e) {
//       setState(() => _err = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _transition(String next) async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     final uid = auth.user?.id;
//     final room = _room;
//     if (token == null || uid == null || room == null) return;
//     setState(() { _busy = true; _err = null; });
//     try {
//       await updateTransactionState(token, room.transaction.id, uid, next);
//       await _load();
//     } catch (e) {
//       setState(() => _err = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _payFromWallet(TxEntity tx) async {
//     final token = context.read<AuthController>().token;
//     if (token == null) return;
//     final amount = double.tryParse(tx.amount) ?? 0;
//     if (amount <= 0) return;
//     final paid = await showTransactionPaymentSheet(
//       context: context,
//       transactionId: tx.id,
//       amount: amount,
//     );
//     if (paid == null || !mounted) return;
//     if (paid != tx.id) {
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute<void>(
//           builder: (_) => TransactionDetailScreen(transactionId: paid),
//         ),
//       );
//       return;
//     }
//     await _load();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthController>();
//     final user = auth.user;
//     final tx = _room?.transaction;

//     final isPublic = tx?.workflow == 'PUBLIC_SHAREABLE';
//     final selfRole = tx != null && user != null
//         ? (user.id == tx.buyerId ? 'buyer' : user.id == tx.sellerId ? 'seller' : 'other')
//         : 'other';

//     final canAccept = tx != null &&
//         selfRole == 'buyer' &&
//         tx.status == 'AWAITING_ACCEPTANCE' &&
//         user != null &&
//         !tx.acceptedPartyIds.contains(user.id);

//     final nextStates = tx != null
//         ? _visibleTransitions(kStatusTransitions[tx.status] ?? [], selfRole)
//         : <String>[];

//     final canPay = tx != null &&
//         selfRole == 'buyer' &&
//         tx.shareToken == null &&
//         tx.status == 'AWAITING_FUNDING';

//     final tabs = tx != null ? _buildTabs(isPublic, selfRole) : <_Tab>[];
//     final activeIndex = tabs.isEmpty ? 0 : _activeTab.clamp(0, tabs.length - 1);

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFF),
//       body: Stack(
//         children: [
//           SafeArea(
//             child: Column(
//               children: [
//                 _AppBar(title: tx != null ? transactionRoomHeading(_room!) : 'Transaction'),
//                 Expanded(
//                   child: tx == null
//                       ? _buildLoading()
//                       : RefreshIndicator(
//                           color: AppColors.gambianBlue,
//                           onRefresh: _load,
//                           child: SingleChildScrollView(
//                             physics: const AlwaysScrollableScrollPhysics(),
//                             padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.stretch,
//                               children: [
//                                 if (_err != null) _InlineError(message: _err!),
//                                 _HeroCard(tx: tx, room: _room!, selfRole: selfRole, isPublic: isPublic),
//                                 const SizedBox(height: 14),
//                                 if (tabs.isNotEmpty) _TabBar(tabs: tabs, activeIndex: activeIndex, onChanged: (i) => setState(() => _activeTab = i)),
//                                 const SizedBox(height: 14),
//                                 _tabBody(
//                                   tabs[activeIndex].id,
//                                   user?.id,
//                                   tx,
//                                   transactionRoomHeading(_room!),
//                                   statusApproxProgress(tx.status),
//                                   canAccept,
//                                   nextStates,
//                                   isPublic,
//                                   canPay,
//                                   selfRole,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoading() {
//     if (_err != null) {
//       return Center(child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Text(_err!, style: TextStyle(color: Colors.red.shade800)),
//       ));
//     }
//     return const Center(child: CircularProgressIndicator());
//   }

//   List<_Tab> _buildTabs(bool isPublic, String selfRole) {
//     if (isPublic) {
//       return [
//         const _Tab('overview', 'Overview', Icons.dashboard_rounded),
//         const _Tab('details', 'Sale', Icons.receipt_long_rounded),
//         const _Tab('parties', 'Parties', Icons.people_alt_outlined),
//         if (selfRole == 'seller') const _Tab('analytics', 'Analytics', Icons.query_stats_rounded),
//         const _Tab('timeline', 'Timeline', Icons.history_rounded),
//       ];
//     }
//     return const [
//       _Tab('overview', 'Overview', Icons.dashboard_rounded),
//       _Tab('details', 'Product', Icons.inventory_2_outlined),
//       _Tab('parties', 'Parties', Icons.people_alt_outlined),
//       _Tab('team', 'Team', Icons.person_add_alt_1_rounded),
//       _Tab('timeline', 'Timeline', Icons.history_rounded),
//     ];
//   }

//   Widget _tabBody(
//     String tabId,
//     String? userId,
//     TxEntity tx,
//     String title,
//     double progressPct,
//     bool canAccept,
//     List<String> nextStates,
//     bool isPublic,
//     bool canPay,
//     String selfRole,
//   ) {
//     switch (tabId) {
//       case 'overview':
//         return _OverviewTab(
//           tx: tx,
//           title: title,
//           progressPct: progressPct,
//           canAccept: canAccept,
//           nextStates: nextStates,
//           isPublic: isPublic,
//           canPay: canPay,
//           selfRole: selfRole,
//           busy: _busy,
//           onAccept: _accept,
//           onPay: () => _payFromWallet(tx),
//           onTransition: _transition,
//           room: _room!,
//         );
//       case 'details':
//         return isPublic ? _PublicSaleTab(tx: tx, miniInfo: _miniInfo) : _ProductTab(tx: tx, room: _room!, miniInfo: _miniInfo);
//       case 'parties':
//         return _PartiesTab(userId: userId, tx: tx, room: _room!);
//       case 'analytics':
//         return _AnalyticsTab(room: _room!);
//       case 'team':
//         return _TeamTab(tx: tx, userId: userId, room: _room!, busy: _busy, onAcceptParticipant: _acceptParticipant, onInviteParticipant: _openInviteParticipant);
//       case 'timeline':
//         return _TimelineTab(room: _room!, userId: userId);
//       default:
//         return const SizedBox.shrink();
//     }
//   }

//   Widget _miniInfo(String label, String value, {bool strong = false}) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFF),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3)),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: strong ? 17 : 13,
//               fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
//               color: strong ? AppColors.gambianBlue : const Color(0xFF0F172A),
//               letterSpacing: strong ? -0.3 : 0,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   List<String> _visibleTransitions(List<String> transitions, String role) {
//     return transitions.where((next) {
//       if (role == 'buyer') return {'COMPLETED', 'DISPUTED'}.contains(next);
//       if (role == 'seller') return {'IN_PROGRESS', 'INSPECTION', 'DISPUTED'}.contains(next);
//       return false;
//     }).toList();
//   }

//   Future<void> _acceptParticipant(String role, String partySide) async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     final uid = auth.user?.id;
//     final txId = _room?.transaction.id;
//     if (token == null || uid == null || txId == null) return;
//     setState(() => _busy = true);
//     try {
//       await acceptTransactionParticipantInvite(token, txId, actorId: uid, role: role, partySide: partySide);
//       await _load();
//     } catch (e) {
//       setState(() => _err = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _openInviteParticipant(String role, String partySide) async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     final uid = auth.user?.id;
//     final u = auth.user;
//     final room = _room;
//     final txId = room?.transaction.id;
//     final tx = room?.transaction;
//     if (token == null || uid == null || txId == null || tx == null || u == null) return;

//     final selected = await showModalBottomSheet<ProfessionalSearchItem>(
//       context: context,
//       isScrollControlled: true,
//       builder: (_) => _InviteSheet(token: token, txId: txId, role: role, partySide: partySide),
//     );
//     if (selected == null || !mounted) return;
//     if (selected.invited) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('That professional is already invited for this slot.')),
//       );
//       return;
//     }

//     String inviterLabel = u.displayName ?? u.fullName ?? u.email ?? u.phone ?? 'Transaction participant';
//     final initial = buildParticipantInviteMessageTemplate(
//       inviterLabel: inviterLabel,
//       partySide: partySide,
//       role: role,
//       productTitle: tx.productTitle,
//       amount: tx.amount,
//       transactionId: tx.id,
//     );
//     final ctrl = TextEditingController(text: initial);
//     final message = await showDialog<String>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text('Invite ${role == 'LAWYER' ? 'Lawyer' : 'Agent'}'),
//         content: SizedBox(
//           width: double.maxFinite,
//           child: TextField(
//             controller: ctrl,
//             maxLines: 14,
//             decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
//           FilledButton(
//             onPressed: () {
//               final t = ctrl.text.trim();
//               if (t.isEmpty) return;
//               Navigator.pop(ctx, t);
//             },
//             child: const Text('Send Invite'),
//           ),
//         ],
//       ),
//     );
//     ctrl.dispose();
//     if (message == null || message.isEmpty || !mounted) return;

//     setState(() => _busy = true);
//     try {
//       await inviteTransactionParticipant(token, txId, actorId: uid, participantUserId: selected.id, role: role, partySide: partySide, message: message);
//       await _load();
//     } catch (e) {
//       setState(() => _err = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }
// }

// // ─── App bar ──────────────────────────────────────────────────────────────────

// class _AppBar extends StatelessWidget {
//   const _AppBar({required this.title});
//   final String title;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: AppColors.gambianBlue,
//       padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
//       child: Row(
//         children: [
//           IconButton(
//             onPressed: () => Navigator.of(context).pop(),
//             icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
//           ),
//           const SizedBox(width: 4),
//           Expanded(
//             child: Text(
//               title,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 17,
//                 fontWeight: FontWeight.w800,
//                 letterSpacing: -0.3,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Hero card ────────────────────────────────────────────────────────────────

// class _HeroCard extends StatelessWidget {
//   const _HeroCard({
//     required this.tx,
//     required this.room,
//     required this.selfRole,
//     required this.isPublic,
//   });

//   final TxEntity tx;
//   final TransactionRoom room;
//   final String selfRole;
//   final bool isPublic;

//   @override
//   Widget build(BuildContext context) {
//     final progress = (statusApproxProgress(tx.status) / 100).clamp(0.0, 1.0);
//     final roleLabel = selfRole == 'buyer' ? 'Buyer' : selfRole == 'seller' ? 'Seller' : 'Collaborator';

//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//         boxShadow: [
//           BoxShadow(color: AppColors.gambianBlue.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Wrap(
//             spacing: 8,
//             runSpacing: 6,
//             children: [
//               _StatusBadge(status: tx.status),
//               _WorkflowBadge(isPublic: isPublic),
//               Text(
//                 '#${tx.id.substring(0, tx.id.length >= 8 ? 8 : tx.id.length)}',
//                 style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace'),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               Expanded(
//                 child: _InfoCell(label: 'Amount', value: '$kCurrencyPrefix${tx.amount}', accent: true),
//               ),
//               const SizedBox(width: 10),
//               Expanded(child: _InfoCell(label: 'Your role', value: roleLabel)),
//             ],
//           ),
//           const SizedBox(height: 14),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(999),
//             child: LinearProgressIndicator(
//               value: progress,
//               minHeight: 6,
//               backgroundColor: const Color(0xFFF1F5F9),
//               valueColor: AlwaysStoppedAnimation<Color>(
//                 tx.status == 'DISPUTED' ? Colors.red.shade400 : AppColors.gambianBlue,
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           _ProgressSteps(status: tx.status),
//         ],
//       ),
//     );
//   }
// }

// class _ProgressSteps extends StatelessWidget {
//   const _ProgressSteps({required this.status});
//   final String status;

//   static const _steps = [
//     ('Created', 0.0),
//     ('Paid', 28.0),
//     ('Delivery', 55.0),
//     ('Done', 100.0),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final pct = statusApproxProgress(status);
//     return Row(
//       children: List.generate(_steps.length, (i) {
//         final done = pct >= _steps[i].$2;
//         return Expanded(
//           child: Column(
//             children: [
//               CircleAvatar(
//                 radius: 13,
//                 backgroundColor: done ? AppColors.gambianBlue : const Color(0xFFF1F5F9),
//                 child: Icon(
//                   done ? Icons.check_rounded : Icons.circle_outlined,
//                   size: 13,
//                   color: done ? Colors.white : Colors.grey.shade400,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 _steps[i].$1,
//                 style: TextStyle(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w700,
//                   color: done ? AppColors.gambianBlue : Colors.grey.shade400,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         );
//       }),
//     );
//   }
// }

// // ─── Tab bar ──────────────────────────────────────────────────────────────────

// class _TabBar extends StatelessWidget {
//   const _TabBar({required this.tabs, required this.activeIndex, required this.onChanged});
//   final List<_Tab> tabs;
//   final int activeIndex;
//   final ValueChanged<int> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF1F5FB),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: List.generate(tabs.length, (i) {
//             final tab = tabs[i];
//             final active = i == activeIndex;
//             return Padding(
//               padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 4),
//               child: GestureDetector(
//                 onTap: () => onChanged(i),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 200),
//                   width: 90,
//                   padding: const EdgeInsets.symmetric(vertical: 10),
//                   decoration: BoxDecoration(
//                     color: active ? Colors.white : Colors.transparent,
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: active
//                         ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))]
//                         : null,
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(tab.icon, size: 16, color: active ? AppColors.gambianBlue : Colors.grey.shade500),
//                       const SizedBox(height: 4),
//                       Text(
//                         tab.label,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w800,
//                           color: active ? AppColors.gambianBlue : Colors.grey.shade600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           }),
//         ),
//       ),
//     );
//   }
// }

// // ─── Overview tab ─────────────────────────────────────────────────────────────

// class _OverviewTab extends StatelessWidget {
//   const _OverviewTab({
//     required this.tx,
//     required this.title,
//     required this.progressPct,
//     required this.canAccept,
//     required this.nextStates,
//     required this.isPublic,
//     required this.canPay,
//     required this.selfRole,
//     required this.busy,
//     required this.onAccept,
//     required this.onPay,
//     required this.onTransition,
//     required this.room,
//   });

//   final TxEntity tx;
//   final String title;
//   final double progressPct;
//   final bool canAccept;
//   final List<String> nextStates;
//   final bool isPublic;
//   final bool canPay;
//   final String selfRole;
//   final bool busy;
//   final VoidCallback onAccept;
//   final VoidCallback onPay;
//   final ValueChanged<String> onTransition;
//   final TransactionRoom room;

//   String _actionLabel(String status) {
//     const map = {
//       'IN_PROGRESS': 'Mark as Shipped',
//       'INSPECTION': 'Sent for Review',
//       'COMPLETED': 'Release Payment',
//       'DISPUTED': 'Raise Dispute',
//     };
//     return map[status] ?? status.replaceAll('_', ' ').toLowerCase();
//   }

//   bool _isDestructive(String status) => status == 'DISPUTED';

//   @override
//   Widget build(BuildContext context) {
//     final nonClose = nextStates.where((s) => s != 'CLOSED').toList();
//     final canClose = canBuyerCloseTransaction(selfRole, buyerId: tx.buyerId, shareToken: tx.shareToken, status: tx.status);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         _Card(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _SectionTitle('Summary'),
//               const SizedBox(height: 14),
//               Row(
//                 children: [
//                   Expanded(child: _InfoCell(label: 'Amount', value: '$kCurrencyPrefix${tx.amount}', accent: true)),
//                   const SizedBox(width: 10),
//                   Expanded(child: _InfoCell(label: 'Status', value: _friendlyStatus(tx.status))),
//                 ],
//               ),
//               const SizedBox(height: 14),
//               _dealSummary(tx),
//             ],
//           ),
//         ),
//         const SizedBox(height: 12),

//         // Actions card
//         if (canAccept || canPay || nonClose.isNotEmpty || canClose)
//           _Card(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 _SectionTitle('Actions'),
//                 const SizedBox(height: 14),
//                 if (canAccept) ...[
//                   _ActionButton(
//                     label: 'Accept Deal',
//                     icon: Icons.handshake_outlined,
//                     onPressed: busy ? null : onAccept,
//                   ),
//                   const SizedBox(height: 10),
//                 ],
//                 if (canPay) ...[
//                   _ActionButton(
//                     label: 'Pay & Fund Escrow',
//                     icon: Icons.account_balance_wallet_outlined,
//                     onPressed: busy ? null : onPay,
//                   ),
//                   const SizedBox(height: 10),
//                 ],
//                 ...nonClose.map((s) {
//                   final destructive = _isDestructive(s);
//                   return Padding(
//                     padding: const EdgeInsets.only(bottom: 10),
//                     child: _ActionButton(
//                       label: _actionLabel(s),
//                       icon: destructive ? Icons.flag_outlined : Icons.arrow_forward_rounded,
//                       onPressed: busy ? null : () => onTransition(s),
//                       destructive: destructive,
//                       filled: !destructive,
//                     ),
//                   );
//                 }),
//                 if (canClose)
//                   _ActionButton(
//                     label: 'Cancel Transaction',
//                     icon: Icons.close_rounded,
//                     onPressed: busy ? null : () => onTransition('CLOSED'),
//                     destructive: true,
//                     filled: false,
//                   ),
//               ],
//             ),
//           ),
//         const SizedBox(height: 12),

//         if (isPublic && tx.shareToken != null)
//           _ShareLinkCard(tx: tx),
//       ],
//     );
//   }

//   Widget _dealSummary(TxEntity tx) {
//     final deal = parseTermsDeal(tx.terms);
//     final f = tx.fundedBy.toUpperCase();
//     final fundingLabel = f.contains('COUNTERPARTY') ? 'Buyer pays' : f.contains('ME') ? 'Seller pays' : tx.fundedBy;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         _Row(k: 'Payment', v: fundingLabel),
//         if (deal?['productTitle'] != null && deal!['productTitle']!.isNotEmpty) ...[
//           const SizedBox(height: 8),
//           _Row(k: 'Item', v: deal['productTitle']!),
//         ],
//       ],
//     );
//   }

//   String _friendlyStatus(String status) {
//     const map = {
//       'AWAITING_ACCEPTANCE': 'Pending Acceptance',
//       'AWAITING_FUNDING': 'Awaiting Payment',
//       'FUNDED': 'Paid — In Escrow',
//       'IN_PROGRESS': 'In Delivery',
//       'INSPECTION': 'Under Review',
//       'COMPLETED': 'Completed',
//       'DISPUTED': 'Disputed',
//       'REFUNDED': 'Refunded',
//       'CLOSED': 'Closed',
//     };
//     return map[status] ?? status.replaceAll('_', ' ');
//   }
// }

// // ─── Shared row widget ────────────────────────────────────────────────────────

// class _Row extends StatelessWidget {
//   const _Row({required this.k, required this.v});
//   final String k;
//   final String v;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFF),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//       ),
//       child: Row(
//         children: [
//           Text(k, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
//           const Spacer(),
//           Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
//         ],
//       ),
//     );
//   }
// }

// // ─── Public sale tab ─────────────────────────────────────────────────────────

// class _PublicSaleTab extends StatelessWidget {
//   const _PublicSaleTab({required this.tx, required this.miniInfo});
//   final TxEntity tx;
//   final Widget Function(String, String, {bool strong}) miniInfo;

//   @override
//   Widget build(BuildContext context) {
//     final terms = _parseTerms(tx.terms);
//     final quantity = tx.quantity ?? 1;
//     final unitPrice = tx.unitPrice ?? tx.amount;
//     final desc = terms['itemDescription'] as String?;
//     final note = terms['sellerNote'] as String?;
//     final deliveryAvailable = terms['deliveryAvailable'] == true;
//     final deliveryPrice = terms['deliveryPrice'];

//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionTitle('Sale Details'),
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               Expanded(child: miniInfo('Quantity', '$quantity')),
//               const SizedBox(width: 10),
//               Expanded(child: miniInfo('Unit Price', '$kCurrencyPrefix$unitPrice')),
//             ],
//           ),
//           const SizedBox(height: 10),
//           _Row(k: 'Total', v: '$kCurrencyPrefix${tx.amount}'),
//           if (desc != null && desc.isNotEmpty) ...[
//             const SizedBox(height: 14),
//             _TextBlock(content: desc),
//           ],
//           if (note != null && note.isNotEmpty) ...[
//             const SizedBox(height: 12),
//             _NoteBlock(note: note),
//           ],
//           const SizedBox(height: 10),
//           _Row(
//             k: 'Delivery',
//             v: deliveryAvailable
//                 ? (deliveryPrice != null ? '$kCurrencyPrefix${deliveryPrice.toString()} available' : 'Available')
//                 : 'Not offered',
//           ),
//           if ((tx.shareToken != null || (tx.sharePath ?? '').isNotEmpty)) ...[
//             const SizedBox(height: 12),
//             _ShareLinkCard(tx: tx),
//           ],
//         ],
//       ),
//     );
//   }

//   Map<String, Object?> _parseTerms(String terms) {
//     try {
//       final raw = jsonDecode(terms);
//       if (raw is Map) {
//         return {
//           'itemDescription': raw['itemDescription'] is String ? (raw['itemDescription'] as String).trim() : null,
//           'sellerNote': raw['sellerNote'] is String ? (raw['sellerNote'] as String).trim() : null,
//           'deliveryAvailable': raw['deliveryAvailable'] == true,
//           'deliveryPrice': raw['deliveryPrice'],
//         };
//       }
//     } catch (_) {}
//     return {'itemDescription': null, 'sellerNote': null, 'deliveryAvailable': false, 'deliveryPrice': null};
//   }
// }

// // ─── Product tab ─────────────────────────────────────────────────────────────

// class _ProductTab extends StatelessWidget {
//   const _ProductTab({required this.tx, required this.room, required this.miniInfo});
//   final TxEntity tx;
//   final TransactionRoom room;
//   final Widget Function(String, String, {bool strong}) miniInfo;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         if (room.product != null)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 14),
//             child: TransactionRoomProductSection(product: room.product!),
//           ),
//         _Card(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _SectionTitle('Deal Summary'),
//               const SizedBox(height: 14),
//               _Row(k: 'Amount', v: '$kCurrencyPrefix${tx.amount}'),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ─── Parties tab ─────────────────────────────────────────────────────────────

// class _PartiesTab extends StatelessWidget {
//   const _PartiesTab({required this.userId, required this.tx, required this.room});
//   final String? userId;
//   final TxEntity tx;
//   final TransactionRoom room;

//   @override
//   Widget build(BuildContext context) {
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionTitle('Buyer & Seller'),
//           const SizedBox(height: 14),
//           _PartyTile(label: 'Buyer', isYou: userId == tx.buyerId, profile: room.parties?.buyer),
//           const SizedBox(height: 10),
//           _PartyTile(label: 'Seller', isYou: userId == tx.sellerId, profile: room.parties?.seller),
//         ],
//       ),
//     );
//   }
// }

// // ─── Analytics tab ───────────────────────────────────────────────────────────

// class _AnalyticsTab extends StatelessWidget {
//   const _AnalyticsTab({required this.room});
//   final TransactionRoom room;

//   @override
//   Widget build(BuildContext context) {
//     final a = room.publicAnalytics;
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionTitle('Link Analytics'),
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               Expanded(child: _InfoCell(label: 'Views', value: '${a?.totalViews ?? 0}')),
//               const SizedBox(width: 10),
//               Expanded(child: _InfoCell(label: 'Unique', value: '${a?.uniqueViewers ?? 0}')),
//             ],
//           ),
//           const SizedBox(height: 10),
//           Row(
//             children: [
//               Expanded(child: _InfoCell(label: 'Paid', value: '${a?.paidCount ?? 0}')),
//               const SizedBox(width: 10),
//               Expanded(child: _InfoCell(label: 'Conversion', value: '${a?.conversionRate ?? '0.0'}%')),
//             ],
//           ),
//           if (a?.recentViewers?.isNotEmpty ?? false) ...[
//             const SizedBox(height: 16),
//             const Text('Recent Viewers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
//             const SizedBox(height: 10),
//             ...(a!.recentViewers!).map((v) => Padding(
//                   padding: const EdgeInsets.only(bottom: 8),
//                   child: _Row(
//                     k: v.label,
//                     v: v.convertedAt == null ? 'Viewed ${v.viewedAt}' : 'Paid ${v.convertedAt}',
//                   ),
//                 )),
//           ],
//         ],
//       ),
//     );
//   }
// }

// // ─── Team tab ────────────────────────────────────────────────────────────────

// class _TeamTab extends StatelessWidget {
//   const _TeamTab({
//     required this.tx,
//     required this.userId,
//     required this.room,
//     required this.busy,
//     required this.onAcceptParticipant,
//     required this.onInviteParticipant,
//   });

//   final TxEntity tx;
//   final String? userId;
//   final TransactionRoom room;
//   final bool busy;
//   final Future<void> Function(String role, String side) onAcceptParticipant;
//   final Future<void> Function(String role, String side) onInviteParticipant;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _ProfessionalCard(
//           role: 'AGENT',
//           tx: tx,
//           userId: userId,
//           room: room,
//           busy: busy,
//           onAccept: onAcceptParticipant,
//           onInvite: onInviteParticipant,
//         ),
//         const SizedBox(height: 14),
//         _ProfessionalCard(
//           role: 'LAWYER',
//           tx: tx,
//           userId: userId,
//           room: room,
//           busy: busy,
//           onAccept: onAcceptParticipant,
//           onInvite: onInviteParticipant,
//         ),
//       ],
//     );
//   }
// }

// class _ProfessionalCard extends StatelessWidget {
//   const _ProfessionalCard({
//     required this.role,
//     required this.tx,
//     required this.userId,
//     required this.room,
//     required this.busy,
//     required this.onAccept,
//     required this.onInvite,
//   });

//   final String role;
//   final TxEntity tx;
//   final String? userId;
//   final TransactionRoom room;
//   final bool busy;
//   final Future<void> Function(String role, String side) onAccept;
//   final Future<void> Function(String role, String side) onInvite;

//   bool get isLawyer => role == 'LAWYER';
//   String get roleWord => isLawyer ? 'Lawyer' : 'Agent';

//   @override
//   Widget build(BuildContext context) {
//     final pt = room.product?.productType;
//     final pricingEnabled = isLawyer ? (pt?.lawyerPricingEnabled ?? false) : (pt?.agentPricingEnabled ?? false);

//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionTitle('${roleWord}s'),
//           const SizedBox(height: 14),
//           _SideBlock(title: "Buyer's $roleWord", role: role, partySide: 'buyer', profile: isLawyer ? room.parties?.buyerLawyer : room.parties?.buyerAgent, inviteStatus: isLawyer ? tx.buyerLawyerInviteStatus : tx.buyerAgentInviteStatus, invitedId: isLawyer ? tx.buyerLawyerId : tx.buyerAgentId, tx: tx, userId: userId, pricingEnabled: pricingEnabled, busy: busy, onAccept: onAccept, onInvite: onInvite),
//           const SizedBox(height: 16),
//           _SideBlock(title: "Seller's $roleWord", role: role, partySide: 'seller', profile: isLawyer ? room.parties?.sellerLawyer : room.parties?.sellerAgent, inviteStatus: isLawyer ? tx.sellerLawyerInviteStatus : tx.sellerAgentInviteStatus, invitedId: isLawyer ? tx.sellerLawyerId : tx.sellerAgentId, tx: tx, userId: userId, pricingEnabled: pricingEnabled, busy: busy, onAccept: onAccept, onInvite: onInvite),
//         ],
//       ),
//     );
//   }
// }

// class _SideBlock extends StatelessWidget {
//   const _SideBlock({
//     required this.title,
//     required this.role,
//     required this.partySide,
//     required this.profile,
//     required this.inviteStatus,
//     required this.invitedId,
//     required this.tx,
//     required this.userId,
//     required this.pricingEnabled,
//     required this.busy,
//     required this.onAccept,
//     required this.onInvite,
//   });

//   final String title;
//   final String role;
//   final String partySide;
//   final PartyProfile? profile;
//   final String inviteStatus;
//   final String? invitedId;
//   final TxEntity tx;
//   final String? userId;
//   final bool pricingEnabled;
//   final bool busy;
//   final Future<void> Function(String, String) onAccept;
//   final Future<void> Function(String, String) onInvite;

//   @override
//   Widget build(BuildContext context) {
//     final canInvite = pricingEnabled && userId != null &&
//         ((partySide == 'buyer' && userId == tx.buyerId) || (partySide == 'seller' && userId == tx.sellerId));
//     final canAcceptInvite = userId != null && invitedId != null && userId == invitedId && inviteStatus == 'PENDING';
//     final roleWord = role == 'LAWYER' ? 'Lawyer' : 'Agent';

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
//         const SizedBox(height: 8),
//         if (profile == null)
//           Text('No one invited yet.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
//         else
//           _PartyTile(label: title, isYou: userId == invitedId, profile: profile),
//         const SizedBox(height: 4),
//         Text('Status: $inviteStatus', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//         if (canInvite) ...[
//           const SizedBox(height: 8),
//           FilledButton.icon(
//             onPressed: busy ? null : () => onInvite(role, partySide),
//             icon: const Icon(Icons.person_add_alt_rounded, size: 16),
//             label: Text('Invite $roleWord'),
//             style: FilledButton.styleFrom(
//               backgroundColor: AppColors.gambianBlue,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
//             ),
//           ),
//         ],
//         if (canAcceptInvite) ...[
//           const SizedBox(height: 8),
//           OutlinedButton(
//             onPressed: busy ? null : () => onAccept(role, partySide),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: AppColors.gambianBlue,
//               side: const BorderSide(color: AppColors.gambianBlue),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
//             ),
//             child: const Text('Accept Invite'),
//           ),
//         ],
//       ],
//     );
//   }
// }

// // ─── Timeline tab ────────────────────────────────────────────────────────────

// class _TimelineTab extends StatelessWidget {
//   const _TimelineTab({required this.room, required this.userId});
//   final TransactionRoom room;
//   final String? userId;

//   @override
//   Widget build(BuildContext context) {
//     final events = room.timeline ?? [];

//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _SectionTitle('Activity'),
//           const SizedBox(height: 14),
//           if (events.isEmpty)
//             Center(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 20),
//                 child: Text('No activity yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
//               ),
//             )
//           else
//             ...List.generate(events.length, (i) {
//               final ev = events[i];
//               final actorLabel = userId != null
//                   ? timelineActorLabel(ev.actorId, room, userId!)
//                   : ev.actorId;
//               final isLast = i == events.length - 1;
//               return Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Column(
//                     children: [
//                       Container(
//                         width: 28,
//                         height: 28,
//                         decoration: BoxDecoration(
//                           color: AppColors.gambianBlue.withValues(alpha: 0.1),
//                           shape: BoxShape.circle,
//                         ),
//                         child: const Icon(Icons.circle, size: 7, color: AppColors.gambianBlue),
//                       ),
//                       if (!isLast)
//                         Container(width: 2, height: 44, color: const Color(0xFFEEF0F6)),
//                     ],
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Padding(
//                       padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFF8FAFF),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: const Color(0xFFEEF0F6)),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(ev.action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
//                             const SizedBox(height: 3),
//                             Text(ev.at, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//                             if (ev.detail.isNotEmpty) ...[
//                               const SizedBox(height: 5),
//                               Text(ev.detail, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
//                             ],
//                             const SizedBox(height: 4),
//                             Text('By: $actorLabel', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             }),
//         ],
//       ),
//     );
//   }
// }

// // ─── Shared small widgets ─────────────────────────────────────────────────────

// class _Card extends StatelessWidget {
//   const _Card({required this.child});
//   final Widget child;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//         boxShadow: [BoxShadow(color: AppColors.gambianBlue.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
//       ),
//       child: child,
//     );
//   }
// }

// class _SectionTitle extends StatelessWidget {
//   const _SectionTitle(this.text);
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2));
//   }
// }

// class _InfoCell extends StatelessWidget {
//   const _InfoCell({required this.label, required this.value, this.accent = false});
//   final String label;
//   final String value;
//   final bool accent;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFF),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3)),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: accent ? 17 : 13,
//               fontWeight: FontWeight.w900,
//               color: accent ? AppColors.gambianBlue : const Color(0xFF0F172A),
//               letterSpacing: accent ? -0.3 : 0,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _StatusBadge extends StatelessWidget {
//   const _StatusBadge({required this.status});
//   final String status;

//   Color get _color {
//     if (status == 'COMPLETED') return const Color(0xFF16A34A);
//     if (status == 'DISPUTED') return const Color(0xFFDC2626);
//     if (status == 'REFUNDED') return const Color(0xFF7C3AED);
//     if (status == 'CLOSED') return Colors.grey.shade500;
//     if ({'FUNDED', 'IN_PROGRESS', 'INSPECTION'}.contains(status)) return AppColors.gambianBlue;
//     return AppColors.gambianEarth;
//   }

//   String get _label {
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
//     return map[status] ?? status.replaceAll('_', ' ');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: BoxDecoration(
//         color: _color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(_label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _color, letterSpacing: 0.2)),
//     );
//   }
// }

// class _WorkflowBadge extends StatelessWidget {
//   const _WorkflowBadge({required this.isPublic});
//   final bool isPublic;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: BoxDecoration(
//         color: AppColors.gambianBlue.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Text(
//         isPublic ? 'Shareable Sale' : 'Private Escrow',
//         style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.gambianBlue),
//       ),
//     );
//   }
// }

// class _ActionButton extends StatelessWidget {
//   const _ActionButton({
//     required this.label,
//     required this.icon,
//     required this.onPressed,
//     this.destructive = false,
//     this.filled = true,
//   });

//   final String label;
//   final IconData icon;
//   final VoidCallback? onPressed;
//   final bool destructive;
//   final bool filled;

//   @override
//   Widget build(BuildContext context) {
//     if (filled && !destructive) {
//       return SizedBox(
//         width: double.infinity,
//         child: FilledButton.icon(
//           onPressed: onPressed,
//           icon: Icon(icon, size: 18),
//           label: Text(label),
//           style: FilledButton.styleFrom(
//             backgroundColor: AppColors.gambianBlue,
//             padding: const EdgeInsets.symmetric(vertical: 13),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//           ),
//         ),
//       );
//     }
//     return SizedBox(
//       width: double.infinity,
//       child: OutlinedButton.icon(
//         onPressed: onPressed,
//         icon: Icon(icon, size: 18),
//         label: Text(label),
//         style: OutlinedButton.styleFrom(
//           foregroundColor: destructive ? const Color(0xFFDC2626) : AppColors.gambianBlue,
//           side: BorderSide(color: destructive ? const Color(0xFFFCA5A5) : AppColors.gambianBlue),
//           padding: const EdgeInsets.symmetric(vertical: 13),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         ),
//       ),
//     );
//   }
// }

// class _PartyTile extends StatelessWidget {
//   const _PartyTile({required this.label, required this.isYou, required this.profile});
//   final String label;
//   final bool isYou;
//   final PartyProfile? profile;

//   @override
//   Widget build(BuildContext context) {
//     final isBuyer = label.toLowerCase().contains('buyer');
//     final accent = isBuyer ? AppColors.gambianBlue : AppColors.gambianEarth;
//     final bg = accent.withValues(alpha: 0.06);
//     final name = profile?.displayName?.trim();
//     final email = profile?.email?.trim();
//     final phone = profile?.phone?.trim();

//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: accent.withValues(alpha: 0.2)),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 20,
//             backgroundColor: accent,
//             child: Text(label.isNotEmpty ? label[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
//                     if (isYou) ...[
//                       const SizedBox(width: 6),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                         decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
//                         child: Text('You', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accent)),
//                       ),
//                     ],
//                   ],
//                 ),
//                 if (name?.isNotEmpty ?? false) ...[
//                   const SizedBox(height: 3),
//                   Text(name!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
//                 ],
//                 if (email?.isNotEmpty ?? false)
//                   SelectableText(email!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
//                 if (phone?.isNotEmpty ?? false)
//                   SelectableText(phone!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
//                 if (profile == null || (name?.isEmpty ?? true) && (email?.isEmpty ?? true) && (phone?.isEmpty ?? true))
//                   Text(profile == null ? 'Slot empty' : 'No contact on file', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TextBlock extends StatelessWidget {
//   const _TextBlock({required this.content});
//   final String content;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFF),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//       ),
//       child: Text(content, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
//     );
//   }
// }

// class _NoteBlock extends StatelessWidget {
//   const _NoteBlock({required this.note});
//   final String note;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.gambianSand.withValues(alpha: 0.3),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.gambianSand),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Seller Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gambianEarth)),
//           const SizedBox(height: 4),
//           Text(note, style: const TextStyle(fontSize: 13, color: AppColors.gambianEarth, height: 1.4)),
//         ],
//       ),
//     );
//   }
// }

// class _InlineError extends StatelessWidget {
//   const _InlineError({required this.message});
//   final String message;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.red.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.red.shade100),
//       ),
//       child: Text(message, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
//     );
//   }
// }

// // ─── Share link card ─────────────────────────────────────────────────────────

// class _ShareLinkCard extends StatelessWidget {
//   const _ShareLinkCard({required this.tx});
//   final TxEntity tx;

//   String get _shareUrl {
//     if (tx.shareToken != null) return '$kShareBaseUrl/pay/${tx.shareToken}';
//     if (tx.sharePath != null) {
//       return tx.sharePath!.startsWith('http') ? tx.sharePath! : '$kShareBaseUrl${tx.sharePath}';
//     }
//     return '';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final url = _shareUrl;
//     if (url.isEmpty) return const SizedBox.shrink();

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.gambianBlue.withValues(alpha: 0.04),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: AppColors.gambianBlue.withValues(alpha: 0.15)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.link_rounded, color: AppColors.gambianBlue, size: 18),
//               SizedBox(width: 8),
//               Text('Payment Link', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.gambianBlue)),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text('Send this link to your buyer via WhatsApp, Instagram, or any app.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 flex: 2,
//                 child: FilledButton.icon(
//                   onPressed: () => Share.share(url, subject: 'Payment Link'),
//                   icon: const Icon(Icons.share_rounded, size: 16),
//                   label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w800)),
//                   style: FilledButton.styleFrom(
//                     backgroundColor: AppColors.gambianBlue,
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () {
//                     Clipboard.setData(ClipboardData(text: url));
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Link copied'), behavior: SnackBarBehavior.floating),
//                     );
//                   },
//                   icon: const Icon(Icons.copy_rounded, size: 16),
//                   label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w800)),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: AppColors.gambianBlue,
//                     side: const BorderSide(color: AppColors.gambianBlue),
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Invite sheet ─────────────────────────────────────────────────────────────

// class _InviteSheet extends StatefulWidget {
//   const _InviteSheet({required this.token, required this.txId, required this.role, required this.partySide});
//   final String token;
//   final String txId;
//   final String role;
//   final String partySide;

//   @override
//   State<_InviteSheet> createState() => _InviteSheetState();
// }

// class _InviteSheetState extends State<_InviteSheet> {
//   final _ctrl = TextEditingController();
//   Timer? _debounce;
//   List<ProfessionalSearchItem> _items = [];
//   String? _disabledReason;
//   bool _busy = false;

//   @override
//   void dispose() {
//     _debounce?.cancel();
//     _ctrl.dispose();
//     super.dispose();
//   }

//   void _onChanged(String _) {
//     _debounce?.cancel();
//     _debounce = Timer(const Duration(milliseconds: 350), _search);
//   }

//   Future<void> _search() async {
//     setState(() => _busy = true);
//     try {
//       final res = await searchTransactionParticipants(widget.token, widget.txId, widget.role, _ctrl.text.trim(), partySide: widget.partySide);
//       if (!mounted) return;
//       setState(() { _items = res.items; _disabledReason = res.disabledReason; });
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final roleWord = widget.role == 'LAWYER' ? 'Lawyer' : 'Agent';
//     return SafeArea(
//       child: Padding(
//         padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: _ctrl,
//               onChanged: _onChanged,
//               decoration: InputDecoration(
//                 labelText: 'Search $roleWord (${widget.partySide})',
//                 hintText: 'Name, email, phone, or ID',
//                 prefixIcon: const Icon(Icons.search_rounded),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
//               ),
//             ),
//             if (_disabledReason != null)
//               Padding(
//                 padding: const EdgeInsets.only(top: 8),
//                 child: Text(_disabledReason!, style: TextStyle(fontSize: 12, color: AppColors.gambianEarth)),
//               ),
//             if (_busy)
//               const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
//             else
//               ConstrainedBox(
//                 constraints: const BoxConstraints(maxHeight: 300),
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: _items.length,
//                   itemBuilder: (_, i) {
//                     final item = _items[i];
//                     return ListTile(
//                       title: Text(item.displayName ?? item.id, style: const TextStyle(fontWeight: FontWeight.w700)),
//                       subtitle: Text([if (item.email?.isNotEmpty ?? false) item.email!, if (item.phone?.isNotEmpty ?? false) item.phone!].join(' · ')),
//                       trailing: item.invited ? const Text('Invited', style: TextStyle(fontSize: 12)) : null,
//                       onTap: item.invited ? null : () => Navigator.of(context).pop(item),
//                     );
//                   },
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }