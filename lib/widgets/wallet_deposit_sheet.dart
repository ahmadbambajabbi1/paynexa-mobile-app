import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/escrow_api.dart' as escrow;
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/modempay_return_urls.dart';
import '../utils/pending_payment_resume.dart';
import 'glass_card.dart';

/// Inline fund-wallet UI for checkout flows. Returns true when wallet was credited.
Future<bool> showWalletDepositSheet({
  required BuildContext context,
  required double suggestedAmount,
  String? currency,
  String? clientRequestIdPrefix,
  String depositReturnContext = 'billings',
  String? depositReturnId,
  String? paymentTransactionId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WalletDepositSheet(
      suggestedAmount: suggestedAmount,
      currency: currency,
      clientRequestIdPrefix: clientRequestIdPrefix,
      depositReturnContext: depositReturnContext,
      depositReturnId: depositReturnId,
      paymentTransactionId: paymentTransactionId,
    ),
  );
  return result == true;
}

class _WalletDepositSheet extends StatefulWidget {
  const _WalletDepositSheet({
    required this.suggestedAmount,
    required this.currency,
    required this.clientRequestIdPrefix,
    required this.depositReturnContext,
    required this.depositReturnId,
    required this.paymentTransactionId,
  });

  final double suggestedAmount;
  final String? currency;
  final String? clientRequestIdPrefix;
  final String depositReturnContext;
  final String? depositReturnId;
  final String? paymentTransactionId;

  @override
  State<_WalletDepositSheet> createState() => _WalletDepositSheetState();
}

class _WalletDepositSheetState extends State<_WalletDepositSheet> {
  bool _loading = true;
  bool _busy = false;
  int _sourceIndex = 0; // 0 card, 1 mobile
  final _amountCtrl = TextEditingController();
  List<Map<String, dynamic>> _cardMethods = const [];
  String? _selectedCardMethodId;
  String? _pendingMobileTransferId;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.suggestedAmount.toStringAsFixed(2);
    _refresh();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _publicError(Object error) {
    final raw = error.toString();
    final lowered = raw.toLowerCase();
    if (error is PlatformException ||
        lowered.contains('secret') ||
        lowered.contains('token') ||
        lowered.contains('apikey')) {
      return 'Payment request failed. Please try again.';
    }
    return raw;
  }

  Future<void> _refresh() async {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty) return;

    setState(() => _loading = true);
    try {
      final methods = await escrow.listPaymentMethods(token);
      final cards = methods.where((m) => m.provider == 'STRIPE' && m.type == 'CARD').toList();
      if (!mounted) return;
      setState(() {
        _cardMethods = cards
            .map(
              (m) => {
                'id': m.id,
                'label': m.label,
                'brand': m.brand,
                'last4': m.last4,
              },
            )
            .toList();
        _selectedCardMethodId ??= cards.isNotEmpty ? cards.first.id : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _parseAmount() {
    final n = double.tryParse(_amountCtrl.text.trim());
    if (n == null || n <= 0) return null;
    return n;
  }

  Future<void> _depositWithCard(double amount) async {
    final token = context.read<AuthController>().token;
    final pmId = _selectedCardMethodId;
    if (token == null || pmId == null || pmId.isEmpty) return;

    final prefix = widget.clientRequestIdPrefix ?? 'deposit';
    final res = await escrow.confirmSavedCardStripeDeposit(
      token,
      amount: amount,
      paymentMethodId: pmId,
      clientRequestId: '$prefix-${DateTime.now().millisecondsSinceEpoch}',
    );
    final credited = res['credited'] == true;
    final status = (res['status'] ?? '').toString().toUpperCase();
    if (!credited && status != 'SUCCEEDED') {
      throw Exception('Card payment is $status. Please try again.');
    }
  }

  Future<void> _startMobileDeposit(double amount) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;

    PendingPaymentResume.save(
      context: widget.depositReturnContext,
      transactionId: widget.paymentTransactionId ?? widget.depositReturnId ?? '',
      ref: widget.depositReturnContext == 'pay' ? widget.depositReturnId : null,
      amount: amount,
    );

    final prefix = widget.clientRequestIdPrefix ?? 'deposit';
    final res = await escrow.createModernPayDepositIntent(
      token,
      amount: amount,
      clientRequestId: '$prefix-${DateTime.now().millisecondsSinceEpoch}',
    );
    final checkoutUrl = (res['checkoutUrl'] ?? '').toString();
    final transferId = (res['transferId'] ?? '').toString();
    if (checkoutUrl.isEmpty || transferId.isEmpty) {
      throw Exception('Unable to start mobile wallet checkout.');
    }

    setState(() => _pendingMobileTransferId = transferId);
    await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm mobile payment', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'After completing payment in Modem Pay, tap Confirm to credit your wallet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColorBlack),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await escrow.confirmModernPayDeposit(token, transferId: transferId);
    final status = (result['status'] ?? '').toString();
    if (status == 'SUCCEEDED') return;
    if (status == 'FAILED' || status == 'CANCELED') {
      throw Exception('Mobile wallet payment was not successful.');
    }
    throw Exception('Payment is still processing. Please confirm again shortly.');
  }

  Future<void> _submit() async {
    final amount = _parseAmount();
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid deposit amount.')),
      );
      return;
    }

    if (_sourceIndex == 0 && (_selectedCardMethodId == null || _cardMethods.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a saved card in Wallet first.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (_sourceIndex == 0) {
        await _depositWithCard(amount);
      } else {
        await _startMobileDeposit(amount);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_publicError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final hasCards = _cardMethods.isNotEmpty;
    final symbol = currencySymbol(widget.currency);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Fund wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Deposit without leaving checkout. Payment continues after funding.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Card')),
                  ButtonSegment(value: 1, label: Text('Mobile')),
                ],
                selected: {_sourceIndex},
                onSelectionChanged: (s) => setState(() => _sourceIndex = s.first),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_sourceIndex == 0) ...[
                  if (!hasCards)
                    Text(
                      'No saved cards. Add one in Wallet, or use mobile wallet.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedCardMethodId,
                      items: _cardMethods
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: (m['id'] ?? '').toString(),
                              child: Text(
                                ((m['label'] ?? '').toString().trim().isNotEmpty)
                                    ? (m['label'] ?? '').toString()
                                    : '${m['brand'] ?? 'card'} •••• ${m['last4'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCardMethodId = v),
                      decoration: const InputDecoration(labelText: 'Saved card'),
                    ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      _pendingMobileTransferId == null
                          ? 'Opens Modem Pay in your browser. Return here to confirm.'
                          : 'Complete payment in Modem Pay, then tap Deposit.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: symbol.isEmpty ? null : '$symbol ',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || _loading
                          ? null
                          : (_sourceIndex == 0 && !hasCards ? null : _submit),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColorBlack),
                      child: Text(_busy ? 'Working…' : 'Deposit'),
                    ),
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
