import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/transactions_api.dart';
import '../api/escrow_api.dart' as escrow_api;
import '../auth/auth_controller.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../utils/currency.dart';
import '../widgets/delivery_address_section.dart';
import '../widgets/transaction_payment_sheet.dart';
import '../utils/pending_payment_resume.dart';
import 'transaction_detail_screen.dart';

class PublicCheckoutScreen extends StatefulWidget {
  const PublicCheckoutScreen({
    super.key,
    required this.ref,
    this.resumePaymentAfterDeposit = false,
  });

  final String ref;
  final bool resumePaymentAfterDeposit;

  @override
  State<PublicCheckoutScreen> createState() => _PublicCheckoutScreenState();
}

class _PublicCheckoutScreenState extends State<PublicCheckoutScreen> {
  PublicTransactionSummary? _summary;
  bool _loading = true;
  bool _busy = false;
  String? _err;
  String? _walletCurrency;
  String? _checkoutTxId;
  Map<String, dynamic>? _paymentQuote;
  bool _deliverySaved = false;
  DeliveryFormValues? _deliverySummary;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.resumePaymentAfterDeposit || PendingPaymentResume.hasPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeResumePayment());
    }
  }

  Future<void> _maybeResumePayment() async {
    if (!mounted || _busy) return;
    final auth = context.read<AuthController>();
    if (auth.token == null || auth.user == null) return;
    await _load();
    if (!mounted || _summary == null) return;
    if (_summary!.deliveryNeeded && !_deliverySaved) return;
    await _pay();
  }

  Future<void> _loadPaymentQuote() async {
    final token = context.read<AuthController>().token;
    final txId = _checkoutTxId;
    if (token == null || txId == null) {
      setState(() => _paymentQuote = null);
      return;
    }
    try {
      final quote = await escrow_api.getTransactionPaymentQuote(token, transactionId: txId);
      if (!mounted) return;
      setState(() => _paymentQuote = quote);
    } catch (_) {
      if (!mounted) return;
      setState(() => _paymentQuote = null);
    }
  }

  Future<void> _loadWalletCurrency() async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) {
      setState(() => _walletCurrency = null);
      return;
    }
    try {
      final wallet = await escrow_api.getWallet(token);
      if (!mounted) return;
      setState(() => _walletCurrency = wallet.currency);
    } catch (_) {
      if (!mounted) return;
      setState(() => _walletCurrency = null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final summary = await getPublicTransactionSummary(widget.ref);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _checkoutTxId = summary.id;
      });
      await _loadWalletCurrency();
      await _loadPaymentQuote();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _err = errorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? get _transactionCurrency =>
      (_paymentQuote?['transactionCurrency'] as String?) ??
      _summary?.currencyCode ??
      _walletCurrency;

  bool get _conversionApplied => _paymentQuote?['conversionApplied'] == true;

  String get _payAmount {
    if (_conversionApplied) {
      return (_paymentQuote?['buyerAmount'] ?? _summary?.totalBuyerPays ?? '0').toString();
    }
    return _summary?.totalBuyerPays ?? '0';
  }

  String? get _payCurrency {
    if (_conversionApplied) {
      return (_paymentQuote?['buyerCurrency'] as String?) ?? _walletCurrency;
    }
    return _transactionCurrency ?? _walletCurrency;
  }

  Future<void> _pay() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final summary = _summary;
    if (token == null || summary == null) return;
    if (summary.deliveryNeeded && !_deliverySaved) {
      setState(() => _err = 'Add a delivery address before paying.');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final amount = double.tryParse(_payAmount) ?? 0;
      if (!mounted) return;
      final paidId = await showTransactionPaymentSheet(
        context: context,
        transactionId: _checkoutTxId ?? summary.id,
        amount: amount,
        currency: _payCurrency,
        depositReturnContext: 'pay',
        depositReturnId: widget.ref,
      );
      PendingPaymentResume.clear();
      if (!mounted || paidId == null) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TransactionDetailScreen(transactionId: paidId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDelivery(DeliveryFormValues values) async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final user = auth.user;
    final summary = _summary;
    if (token == null || user == null || summary == null) return;

    final result = await saveDeliveryDetails(
      token,
      summary.id,
      actorId: user.id,
      details: values.toJson(),
    );
    final nextId = (result['transactionId'] ?? summary.id).toString();
    setState(() {
      _checkoutTxId = nextId;
      _deliverySummary = values;
      _deliverySaved = true;
    });
    await _loadPaymentQuote();
  }

  void _openRoom(String transactionId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TransactionDetailScreen(transactionId: transactionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final token = auth.token;
    final summary = _summary;
    final isParty =
        summary != null &&
        user != null &&
        (user.id == summary.sellerId || user.id == summary.buyerId);
    final isSeller =
        summary != null && user != null && user.id == summary.sellerId;
    final assignedToOther =
        summary?.buyerId != null &&
        user != null &&
        summary!.buyerId != user.id &&
        summary.sellerId != user.id;
    final shouldHideDetails = summary?.isFundedOrBeyond == true && !isParty;
    final displayCurrency = _transactionCurrency;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryColorBlack,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_err != null && summary == null)
              _message(_err!, color: Colors.red.shade700)
            else if (summary != null && shouldHideDetails)
              _message('This transaction is only available to the buyer and seller.')
            else if (summary != null) ...[
              _checkoutCard(summary, displayCurrency),
              if ((summary.itemDescription ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _textPanel('Item details', summary.itemDescription!),
              ],
              if ((summary.sellerNote ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _textPanel('Seller note', summary.sellerNote!),
              ],
              if (_err != null) ...[
                const SizedBox(height: 16),
                _message(_err!, color: Colors.red.shade700),
              ],
              const SizedBox(height: 20),
              if (summary.isFundedOrBeyond && isParty)
                _primaryButton('Open transaction room', () => _openRoom(summary.id))
              else if (isSeller)
                _primaryButton('Open seller room', () => _openRoom(summary.id))
              else if (assignedToOther)
                _message('This transaction is already assigned to another buyer.')
              else if (user == null)
                _message('Sign in to pay for this transaction.')
              else ...[
                if (summary.deliveryNeeded && token != null) ...[
                  DeliveryAddressSection(
                    token: token,
                    confirmed: _deliverySaved ? _deliverySummary : null,
                    onClear: () => setState(() {
                      _deliverySaved = false;
                      _deliverySummary = null;
                    }),
                    onConfirm: _saveDelivery,
                  ),
                  const SizedBox(height: 16),
                ],
                _primaryButton(
                  _busy ? 'Processing…' : 'Pay now',
                  (summary.deliveryNeeded && !_deliverySaved) || _busy ? null : _pay,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _checkoutCard(PublicTransactionSummary s, String? currency) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primaryColorBlack,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _badge(Icons.shield_outlined, 'Escrow protected'),
                    const SizedBox(width: 8),
                    _badge(Icons.lock_outline, 'Secure checkout'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Secure shared transaction',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.item,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sold by ${s.seller}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        moneyText(s.totalBuyerPays, currency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _row('Status', _formatStatus(s.status)),
                _row('Quantity', '${s.quantity}'),
                _row('Unit price', moneyText(s.unitPrice, currency)),
                _row('Subtotal', moneyText(s.amount, currency)),
                if (_conversionApplied) ...[
                  _row('Your currency', (_paymentQuote?['buyerCurrency'] ?? '').toString()),
                  _row('You pay', moneyText(_payAmount, _payCurrency)),
                  _row('Exchange rate', (_paymentQuote?['displayRate'] ?? '').toString()),
                ],
                const Divider(height: 24),
                _row('Total', moneyText(s.totalBuyerPays, currency), strong: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed, {IconData? icon}) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.payment),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryColorBlack,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _textPanel(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
        ],
      ),
    );
  }

  Widget _message(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primaryColorBlack).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.primaryColorBlack,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? AppColors.primaryColorBlack : Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? AppColors.primaryColorBlack : Colors.grey.shade900,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              fontSize: strong ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) => status
      .replaceAll('_', ' ')
      .toLowerCase()
      .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());
}
