import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/transactions_api.dart';
import '../auth/auth_controller.dart';
import '../config/constants.dart';
import '../models/transaction_models.dart';
import '../theme/app_colors.dart';
import '../widgets/transaction_payment_sheet.dart';
import 'transaction_detail_screen.dart';

class PublicCheckoutScreen extends StatefulWidget {
  const PublicCheckoutScreen({super.key, required this.ref});

  final String ref;

  @override
  State<PublicCheckoutScreen> createState() => _PublicCheckoutScreenState();
}

class _PublicCheckoutScreenState extends State<PublicCheckoutScreen> {
  PublicTransactionSummary? _summary;
  bool _loading = true;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final summary = await getPublicTransactionSummary(widget.ref);
      if (!mounted) return;
      setState(() => _summary = summary);
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

  Future<void> _claimAndPay() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final user = auth.user;
    final summary = _summary;
    if (token == null || user == null || summary == null) return;

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final claimed = await claimPublicTransaction(token, widget.ref, user.id);
      final amount = double.tryParse(summary.totalBuyerPays) ?? 0;
      if (!mounted) return;
      final paidId = await showTransactionPaymentSheet(
        context: context,
        transactionId: claimed.transactionId,
        amount: amount,
      );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_err != null && summary == null)
              _message(_err!, color: Colors.red.shade700)
            else if (summary != null && shouldHideDetails)
              _message(
                'This transaction is only available to the buyer and seller.',
              )
            else if (summary != null) ...[
              Text(
                summary.item,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColorBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sold by ${summary.seller}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _summaryCard(summary),
              if ((summary.itemDescription ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _textPanel('Details', summary.itemDescription!),
              ],
              if ((summary.sellerNote ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _textPanel('Seller note', summary.sellerNote!),
              ],
              if (_err != null) ...[
                const SizedBox(height: 16),
                _message(_err!, color: Colors.red.shade700),
              ],
              const SizedBox(height: 22),
              if (summary.isFundedOrBeyond && isParty)
                FilledButton(
                  onPressed: _busy ? null : () => _openRoom(summary.id),
                  child: const Text('Open transaction room'),
                )
              else if (isSeller)
                FilledButton(
                  onPressed: _busy ? null : () => _openRoom(summary.id),
                  child: const Text('Open seller room'),
                )
              else if (assignedToOther)
                _message(
                  'This transaction is already assigned to another buyer.',
                )
              else if (user == null)
                _message('Sign in to pay for this transaction.')
              else
                FilledButton.icon(
                  onPressed: _busy ? null : _claimAndPay,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(_busy ? 'Processing...' : 'Pay now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryColorBlack,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(PublicTransactionSummary s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _row('Status', _formatStatus(s.status)),
          _row('Quantity', '${s.quantity}'),
          _row('Unit price', '$kCurrencyPrefix${s.unitPrice}'),
          _row('Subtotal', '$kCurrencyPrefix${s.amount}'),
          _row('Protection fee', '$kCurrencyPrefix${s.protectionFee}'),
          const Divider(height: 20),
          _row('Total', '$kCurrencyPrefix${s.totalBuyerPays}', strong: true),
        ],
      ),
    );
  }

  Widget _textPanel(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColorBlack.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
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
                color: strong
                    ? AppColors.primaryColorBlack
                    : Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong
                  ? AppColors.primaryColorBlack
                  : Colors.grey.shade900,
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
