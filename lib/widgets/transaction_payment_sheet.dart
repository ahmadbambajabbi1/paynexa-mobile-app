import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import '../api/escrow_api.dart' as escrow;
import '../auth/auth_controller.dart';
import '../config/constants.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

/// Returns the transaction id that was funded (may differ after claiming a share link).
Future<String?> showTransactionPaymentSheet({
  required BuildContext context,
  required String transactionId,
  required double amount,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionPaymentSheet(
      transactionId: transactionId,
      amount: amount,
    ),
  );
}

class _TransactionPaymentSheet extends StatefulWidget {
  const _TransactionPaymentSheet({
    required this.transactionId,
    required this.amount,
  });

  final String transactionId;
  final double amount;

  @override
  State<_TransactionPaymentSheet> createState() => _TransactionPaymentSheetState();
}

class _TransactionPaymentSheetState extends State<_TransactionPaymentSheet> {
  bool _loading = true;
  bool _busy = false;
  int _modeIndex = 0;
  String _walletBalance = '0';
  List<Map<String, dynamic>> _cardMethods = const [];
  String? _selectedCardMethodId;

  double _parseBalance() => double.tryParse(_walletBalance) ?? 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null || token.isEmpty) return;

    setState(() => _loading = true);
    try {
      final cfg = await escrow.getEscrowConfig(token);
      final pk = (cfg['stripePublishableKey'] ?? '').toString().trim();
      if (pk.isNotEmpty) {
        Stripe.publishableKey = pk;
      }

      final w = await escrow.getWallet(token);
      final methods = await escrow.listPaymentMethods(token);
      final cards = methods.where((m) => m.provider == 'STRIPE' && m.type == 'CARD').toList();

      setState(() {
        _walletBalance = w.balance;
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

  Future<void> _payWithWallet() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null || token.isEmpty) return;

    setState(() => _busy = true);
    try {
      final res = await escrow.payTransactionFromWallet(
        token,
        transactionId: widget.transactionId,
      );
      final paidId = (res['transactionId'] ?? widget.transactionId).toString();
      if (!mounted) return;
      Navigator.of(context).pop(paidId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payWithCard() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null || token.isEmpty) return;
    final pmId = _selectedCardMethodId;
    if (pmId == null || pmId.isEmpty) return;

    setState(() => _busy = true);
    try {
      final deposit = await escrow.createStripeDepositIntent(
        token,
        amount: widget.amount,
        paymentMethodId: pmId,
        clientRequestId: 'tx-deposit-${widget.transactionId}',
      );
      if (!mounted) return;
      final clientSecret = (deposit['clientSecret'] ?? '').toString();
      final transferId = (deposit['transferId'] ?? '').toString();
      if (clientSecret.isEmpty || transferId.isEmpty) {
        throw Exception('Unable to start card payment.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: kAppName,
          allowsDelayedPaymentMethods: true,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;

      await escrow.syncStripeDeposit(token, transferId: transferId);
      final res = await escrow.payTransactionFromWallet(
        token,
        transactionId: widget.transactionId,
      );
      final paidId = (res['transactionId'] ?? widget.transactionId).toString();
      if (!mounted) return;
      Navigator.of(context).pop(paidId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWallet = _parseBalance() + 1e-9 >= widget.amount && widget.amount > 0;
    final hasCards = _cardMethods.isNotEmpty;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

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
                'Pay for transaction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Amount due: $kCurrencyPrefix${widget.amount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Wallet')),
                  ButtonSegment(value: 1, label: Text('Card')),
                ],
                selected: {_modeIndex},
                onSelectionChanged: (s) => setState(() => _modeIndex = s.first),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_modeIndex == 0) ...[
                  _InfoRow(
                    label: 'Wallet balance',
                    value: '$kCurrencyPrefix$_walletBalance',
                    valueColor: canWallet ? AppColors.gambianGreen : AppColors.gambianRed,
                  ),
                  if (!canWallet) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Insufficient wallet balance. Add funds in Wallet or pay with card.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                    ),
                  ],
                ] else ...[
                  if (!hasCards)
                    Text(
                      'No saved cards found. Add a card in Wallet first.',
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
                  const SizedBox(height: 8),
                  Text(
                    'Card payment tops up your wallet, then pays from wallet into escrow.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || _loading
                          ? null
                          : (_modeIndex == 0
                                ? (canWallet ? _payWithWallet : null)
                                : (hasCards ? _payWithCard : null)),
                      child: Text(_busy ? 'Processing…' : 'Pay now'),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: valueColor ?? Colors.grey.shade900,
          ),
        ),
      ],
    );
  }
}
