import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_error.dart';
import '../api/escrow_api.dart';
import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../models/wallet_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../models/me_user.dart';
import '../utils/invite_participant_message.dart';
import '../utils/currency.dart';
import '../utils/parse_terms.dart';
import '../utils/transaction_room_title.dart';
import '../utils/transaction_ui.dart';
import '../widgets/transaction_payment_sheet.dart';
import '../widgets/raise_dispute_sheet.dart';
import '../widgets/dispute_thread_section.dart';
import '../widgets/transaction_room_product_section.dart';

class _TransactionDetailTab {
  const _TransactionDetailTab(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.resumePaymentAfterDeposit = false,
  });

  final String transactionId;
  final bool resumePaymentAfterDeposit;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionRoom? _room;
  String? _err;
  bool _busy = false;
  int _activeTab = 0;
  String? _walletCurrency;

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
      final results = await Future.wait<Object>([
        getTransactionRoom(token, widget.transactionId),
        getWallet(token),
      ]);
      final r = results[0] as TransactionRoom;
      final wallet = results[1] as WalletSummary;
      setState(() {
        _room = r;
        _walletCurrency = wallet.currency;
      });
      if (widget.resumePaymentAfterDeposit) {
        await _maybeResumePayment(r);
      }
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
    if (next == 'DISPUTED') {
      await RaiseDisputeSheet.show(
        context,
        onSubmit: (reason) async {
          setState(() {
            _busy = true;
            _err = null;
          });
          try {
            await raiseTransactionDispute(
              token,
              room.transaction.id,
              actorId: uid,
              reason: reason,
            );
            await _load();
          } catch (e) {
            setState(() => _err = errorMessage(e));
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
      );
      return;
    }
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
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(title: const Text('Transaction')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Align(
              //   alignment: Alignment.centerLeft,
              //   child: TextButton.icon(
              //     onPressed: () => Navigator.of(context).pop(),
              //     icon: const Icon(Icons.arrow_back_rounded),
              //     label: const Text('Back to transactions'),
              //   ),
              // ),
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
          'parties',
          'Parties',
          Icons.people_alt_outlined,
        ),
        // Analytics — coming soon
        // if (selfRole == 'seller')
        //   const _TransactionDetailTab(
        //     'analytics',
        //     'Analytics',
        //     Icons.query_stats_rounded,
        //   ),
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
        return isPublicShareable ? _publicSaleDetailsSection(tx) : _productTab(tx);
      case 'parties':
        return _partiesTab(userId, tx);
      // case 'analytics':
      //   return _publicAnalyticsTab();
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

  Future<void> _maybeResumePayment(TransactionRoom room) async {
    final auth = context.read<AuthController>();
    final userId = auth.user?.id;
    final tx = room.transaction;
    if (userId == null || tx.buyerId != userId) return;
    if (tx.status != 'AWAITING_FUNDING') return;
    await _payFromWallet(tx);
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
      depositReturnContext: 'transaction',
      depositReturnId: tx.id,
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
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final active = activeIndex == index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 6),
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryColorBlack
                        : Colors.transparent,
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
                        textAlign: TextAlign.center,
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
            ),
          );
        }),
      ),
    );
  }

  Widget _transactionHero(
    TxEntity tx,
    String title,
    double progressPct,
    String selfRole,
  ) {
    final roleLabel = selfRole == 'buyer'
        ? 'Buyer'
        : selfRole == 'seller'
        ? 'Seller'
        : 'Collaborator';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${tx.id.substring(0, tx.id.length >= 8 ? 8 : tx.id.length)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: displayHeading(context).copyWith(fontSize: 25)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    'Amount',
                    moneyText(tx.amount, _walletCurrency),
                    strong: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _miniInfo('Role', roleLabel)),
              ],
            ),
            const SizedBox(height: 14),
            _progressBar(progressPct),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBF2)),
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
              color: strong
                  ? AppColors.primaryColorBlack
                  : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: displayHeading(context).copyWith(fontSize: 18),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EBF2)),
          Padding(padding: const EdgeInsets.all(16), child: child),
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

  bool _showDisputeSection(TxEntity tx, String selfRole) {
    if (selfRole != 'buyer' && selfRole != 'seller') return false;
    if (tx.buyerId == null || tx.buyerId!.isEmpty) return false;
    const eligible = {
      'FUNDED',
      'IN_PROGRESS',
      'INSPECTION',
      'DISPUTED',
      'COMPLETED',
      'REFUNDED',
    };
    return eligible.contains(tx.status) ||
        (_room?.disputes.isNotEmpty ?? false);
  }

  Widget? _disputeSection(
    AuthController auth,
    MeUser? user,
    TxEntity tx,
    String selfRole,
  ) {
    if (user == null || auth.token == null || _room == null) return null;
    if (!_showDisputeSection(tx, selfRole)) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DisputeThreadSection(
        token: auth.token!,
        transactionId: tx.id,
        actorId: user.id,
        selfRole: selfRole == 'buyer' || selfRole == 'seller' ? selfRole : null,
        disputes: _room!.disputes,
        onReload: _load,
        onOpenNewDispute: () => _transition('DISPUTED'),
      ),
    );
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
    final auth = context.read<AuthController>();
    final user = auth.user;
    final dispute = _disputeSection(auth, user, tx, selfRole);
    final openActions = nextStates.where((s) => s != 'CLOSED').toList();
    final canClose = canBuyerCloseTransaction(
      selfRole,
      buyerId: tx.buyerId,
      shareToken: tx.shareToken,
      status: tx.status,
    );
    final hasActions =
        canAccept ||
        canPayFromWallet ||
        openActions.isNotEmpty ||
        canClose;

    if (isPublicShareable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _publicSaleDetailsSection(tx),
          if (hasActions) ...[
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Actions',
              subtitle: 'Available actions',
              child: _actionGroup(
                tx: tx,
                canAccept: canAccept,
                canPayFromWallet: canPayFromWallet,
                nextStates: openActions,
                canClose: canClose,
              ),
            ),
          ],
          if (dispute != null) dispute,
        ],
      );
    }

    if (!hasActions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCard(
            title: 'Deal summary',
            subtitle: 'Funding and amount for this escrow',
            child: _dealSummary(tx),
          ),
          if (dispute != null) dispute,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Deal summary',
          subtitle: 'Funding and amount for this escrow',
          child: _dealSummary(tx),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          title: 'Actions',
          subtitle: 'Available actions',
          child: _actionGroup(
            tx: tx,
            canAccept: canAccept,
            canPayFromWallet: canPayFromWallet,
            nextStates: openActions,
            canClose: canClose,
          ),
        ),
        if (dispute != null) dispute,
      ],
    );
  }

  String selfRoleLabel(String selfRole) {
    if (selfRole == 'buyer') return 'Buyer';
    if (selfRole == 'seller') return 'Seller';
    return 'Collaborator';
  }

  Widget _actionGroup({
    required TxEntity tx,
    required bool canAccept,
    required bool canPayFromWallet,
    required List<String> nextStates,
    required bool canClose,
  }) {
    final actions = <Widget>[];

    if (canAccept) {
      actions.add(
        _ActionButton(
          label: 'Accept transaction',
          icon: Icons.check_rounded,
          onPressed: _busy ? null : _accept,
          kind: _ActionButtonKind.primary,
        ),
      );
    }
    if (canPayFromWallet) {
      actions.add(
        _ActionButton(
          label: 'Pay from wallet',
          icon: Icons.account_balance_wallet_outlined,
          onPressed: _busy ? null : () => _payFromWallet(tx),
          kind: _ActionButtonKind.primary,
        ),
      );
    }
    for (final next in nextStates) {
      actions.add(
        _ActionButton(
          label: transitionActionLabel(next),
          icon: _transitionIcon(next),
          onPressed: _busy ? null : () => _transition(next),
          kind: _ActionButtonKind.secondary,
        ),
      );
    }
    if (canClose) {
      actions.add(
        _ActionButton(
          label: 'Close transaction',
          icon: Icons.close_rounded,
          onPressed: _busy ? null : () => _transition('CLOSED'),
          kind: _ActionButtonKind.destructive,
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(actions.length, (index) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
              child: actions[index],
            );
          }),
        ],
      ),
    );
  }

  IconData _transitionIcon(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return Icons.play_arrow_rounded;
      case 'INSPECTION':
        return Icons.fact_check_outlined;
      case 'COMPLETED':
        return Icons.done_all_rounded;
      case 'DISPUTED':
        return Icons.report_problem_outlined;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  Widget _timelineTab(String? userId) {
    final events = _room?.timeline ?? const <TimelineEvent>[];
    return _sectionCard(
      title: 'Timeline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              final displayDetail = formatTimelineDetail(ev.action, ev.detail);
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
                          color: AppColors.primaryColorBlack,
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
                              formatTimelineAction(ev.action, ev.detail),
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
                            if (displayDetail.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                displayDetail,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'By: $actorLabel',
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
    return _sectionCard(
      title: 'Buyer and seller',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            child: TransactionRoomProductSection(
              product: _room!.product!,
              currency: _walletCurrency,
            ),
          ),
        _sectionCard(
          title: 'Deal summary',
          subtitle: 'Funding and amount for this escrow',
          child: _dealSummary(tx),
        ),
      ],
    );
  }

  Widget _publicSaleDetailsSection(TxEntity tx) {
    final terms = _parsePublicTerms(tx.terms);
    final quantity = tx.quantity ?? 1;
    final unitPrice = tx.unitPrice ?? tx.amount;
    final itemDescription = terms['itemDescription'] as String?;
    final sellerNote = terms['sellerNote'] as String?;
    final deliveryNeeded = terms['deliveryNeeded'] == true;

    return _sectionCard(
      title: 'Sale details',
      subtitle: 'Item, quantity, delivery, and buyer checkout link',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _miniInfo('Quantity', '$quantity')),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfo(
                  'Unit price',
                  moneyText(unitPrice, _walletCurrency),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _summaryRow('Total', moneyText(tx.amount, _walletCurrency)),
          const SizedBox(height: 10),
          _summaryRow(
            'Delivery',
            deliveryNeeded ? 'Delivery tracked' : 'Payment only',
          ),
          if (itemDescription != null && itemDescription.isNotEmpty) ...[
            const SizedBox(height: 14),
            _textBlock('Description', itemDescription),
          ],
          if (sellerNote != null && sellerNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            _textBlock('Seller note', sellerNote),
          ],
          if (tx.shareToken != null || (tx.sharePath ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _shareLinkCard(tx),
          ],
        ],
      ),
    );
  }

  Widget _textBlock(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: Colors.grey.shade800, height: 1.42),
          ),
        ],
      ),
    );
  }

  // Analytics — coming soon
  // Widget _publicAnalyticsTab() {
  //   final analytics = _room?.publicAnalytics;
  //   final totalViews = analytics?.totalViews ?? 0;
  //   final uniqueViewers = analytics?.uniqueViewers ?? 0;
  //   final paidCount = analytics?.paidCount ?? 0;
  //   final conversionRate = analytics?.conversionRate ?? '0.0';
  //   final viewers =
  //       analytics?.recentViewers ?? const <PublicTransactionViewer>[];
  //
  //   return _sectionCard(
  //     title: 'Link analytics',
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         Row(
  //           children: [
  //             Expanded(child: _miniInfo('Views', '$totalViews')),
  //             const SizedBox(width: 10),
  //             Expanded(child: _miniInfo('Unique', '$uniqueViewers')),
  //           ],
  //         ),
  //         const SizedBox(height: 10),
  //         Row(
  //           children: [
  //             Expanded(child: _miniInfo('Paid', '$paidCount')),
  //             const SizedBox(width: 10),
  //             Expanded(child: _miniInfo('Conversion', '$conversionRate%')),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         Text(
  //           'Recent viewers',
  //           style: TextStyle(
  //             fontWeight: FontWeight.w800,
  //             color: Colors.grey.shade900,
  //           ),
  //         ),
  //         const SizedBox(height: 10),
  //         if (viewers.isEmpty)
  //           Text(
  //             'No link views yet.',
  //             style: TextStyle(color: Colors.grey.shade600),
  //           )
  //         else
  //           ...viewers.map(
  //             (viewer) => Padding(
  //               padding: const EdgeInsets.only(bottom: 10),
  //               child: _summaryRow(
  //                 viewer.label,
  //                 viewer.convertedAt == null
  //                     ? 'Viewed ${viewer.viewedAt}'
  //                     : 'Paid ${viewer.convertedAt}',
  //               ),
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

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

    return _sectionCard(
      title: isLawyer ? 'Lawyers' : 'Agents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

  // Widget _statusBadge(String status) {
  //   final done = status == 'COMPLETED' || status == 'CLOSED';
  //   final disputed = status == 'DISPUTED';
  //   Color bg = AppColors.gambianSand.withValues(alpha: 0.65);
  //   Color fg = AppColors.gambianEarth;
  //   if (done ||
  //       status == 'AWAITING_FUNDING' ||
  //       status == 'FUNDED' ||
  //       status == 'IN_PROGRESS' ||
  //       status == 'INSPECTION') {
  //     bg = Colors.blue.shade50;
  //     fg = AppColors.primaryColorBlack;
  //   } else if (disputed) {
  //     bg = Colors.red.shade100;
  //     fg = Colors.red.shade900;
  //   }
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: bg,
  //       borderRadius: BorderRadius.circular(20),
  //     ),
  //     child: Text(
  //       formatStatus(status),
  //       style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
  //     ),
  //   );
  // }

  Widget _progressBar(double pct) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.primaryColorBlack,
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
                        ? AppColors.primaryColorBlack
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
    final accent = isBuyerTone
        ? AppColors.primaryColorBlack
        : AppColors.gambianEarth;
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
                            color: AppColors.primaryColorBlack,
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
        color: AppColors.primaryColorBlack.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColorBlack.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: AppColors.primaryColorBlack,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Shareable Payment Link',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primaryColorBlack,
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
                    Share.share(shareUrl, subject: 'Escrow Payment Link');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryColorBlack,
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
                    foregroundColor: AppColors.primaryColorBlack,
                    side: const BorderSide(color: AppColors.primaryColorBlack),
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
        _summaryRow('Amount', moneyText(tx.amount, _walletCurrency)),
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
        border: Border.all(color: const Color(0xFFE8EBF2)),
        color: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
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

enum _ActionButtonKind { primary, secondary, destructive }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.kind,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _ActionButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final destructive = kind == _ActionButtonKind.destructive;
    final primary = kind == _ActionButtonKind.primary;
    final fg = destructive
        ? Colors.red.shade800
        : primary
        ? Colors.white
        : AppColors.primaryColorBlack;
    final bg = destructive
        ? Colors.red.shade50
        : primary
        ? AppColors.primaryColorBlack
        : Colors.white;
    final border = destructive
        ? Colors.red.shade200
        : primary
        ? AppColors.primaryColorBlack
        : const Color(0xFFE8EBF2);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: onPressed == null ? 0.55 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.16)
                        : fg.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: fg, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: fg, size: 20),
              ],
            ),
          ),
        ),
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
