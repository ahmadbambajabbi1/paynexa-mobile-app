import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/escrow_api.dart' as escrow;
import '../auth/auth_controller.dart';
import '../utils/currency.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';
import 'wallet_deposit_sheet.dart';

/// Returns the transaction id that was funded (may differ after claiming a share link).
Future<String?> showTransactionPaymentSheet({
  required BuildContext context,
  required String transactionId,
  required double amount,
  String? currency,
  String depositReturnContext = 'transaction',
  String? depositReturnId,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionPaymentSheet(
      transactionId: transactionId,
      amount: amount,
      currency: currency,
      depositReturnContext: depositReturnContext,
      depositReturnId: depositReturnId ?? transactionId,
    ),
  );
}

class _TransactionPaymentSheet extends StatefulWidget {
  const _TransactionPaymentSheet({
    required this.transactionId,
    required this.amount,
    this.currency,
    required this.depositReturnContext,
    required this.depositReturnId,
  });

  final String transactionId;
  final double amount;
  final String? currency;
  final String depositReturnContext;
  final String depositReturnId;

  @override
  State<_TransactionPaymentSheet> createState() => _TransactionPaymentSheetState();
}

class _TransactionPaymentSheetState extends State<_TransactionPaymentSheet> {
  bool _loading = true;
  bool _busy = false;
  int _modeIndex = 0;
  String _walletBalance = '0';
  String? _walletCurrency;

  String? get _displayCurrency => widget.currency ?? _walletCurrency;
  List<Map<String, dynamic>> _cardMethods = const [];
  String? _selectedCardMethodId;

  double _parseBalance() => double.tryParse(_walletBalance) ?? 0;

  double get _deficit {
    final gap = widget.amount - _parseBalance();
    return gap > 0 ? gap : 0;
  }

  Future<void> _fundWallet() async {
    final funded = await showWalletDepositSheet(
      context: context,
      suggestedAmount: _deficit > 0 ? _deficit : widget.amount,
      currency: _displayCurrency,
      clientRequestIdPrefix: 'tx-deposit-${widget.transactionId}',
      depositReturnContext: widget.depositReturnContext,
      depositReturnId: widget.depositReturnId,
      paymentTransactionId: widget.transactionId,
    );
    if (!funded || !mounted) return;
    await _refresh();
    if (!mounted) return;
    if (_parseBalance() + 1e-9 >= widget.amount) {
      await _payWithWallet();
    }
  }

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
      final w = await escrow.getWallet(token);
      final methods = await escrow.listPaymentMethods(token);
      final cards = methods.where((m) => m.provider == 'STRIPE' && m.type == 'CARD').toList();

      setState(() {
        _walletBalance = w.balance;
        _walletCurrency = w.currency;
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
      final deposit = await escrow.confirmSavedCardStripeDeposit(
        token,
        amount: widget.amount,
        paymentMethodId: pmId,
        clientRequestId: 'tx-deposit-${widget.transactionId}',
      );
      if (!mounted) return;
      final credited = deposit['credited'] == true;
      final status = (deposit['status'] ?? '').toString().toUpperCase();
      if (!credited && status != 'SUCCEEDED') {
        throw Exception('Card payment is $status. Please try again or use Wallet.');
      }

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
    final needsFunding = _modeIndex == 0 && !canWallet && widget.amount > 0;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          backgroundColor: AppColors.primaryColorBlack, // now works
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pay for transaction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Amount due: ${moneyText(widget.amount, _displayCurrency)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              // Segmented button with dark theme
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Wallet')),
                  ButtonSegment(value: 1, label: Text('Card')),
                ],
                selected: {_modeIndex},
                onSelectionChanged: (s) => setState(() => _modeIndex = s.first),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.primaryColorBlack;
                    return Colors.white;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return Colors.white;
                    return Colors.transparent;
                  }),
                  overlayColor: WidgetStateProperty.all(Colors.white24),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                )
              else ...[
                if (_modeIndex == 0) ...[
                  _InfoRow(
                    label: 'Wallet balance',
                    value: moneyText(_walletBalance, _displayCurrency),
                    valueColor: canWallet ? AppColors.gambianGreen : AppColors.gambianRed,
                    labelColor: Colors.white70,
                  ),
                  if (!canWallet) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Amount needed',
                      value: moneyText(_deficit, _displayCurrency),
                      valueColor: Colors.orange.shade300,
                      labelColor: Colors.white70,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Insufficient wallet balance. Deposit here or pay with card.',
                      style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
                    ),
                  ],
                ] else ...[
                  if (!hasCards)
                    Text(
                      'No saved cards found. Add a card in Wallet first.',
                      style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
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
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCardMethodId = v),
                      decoration: const InputDecoration(
                        labelText: 'Saved card',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Card payment tops up your wallet, then pays from wallet into escrow.',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
              if (needsFunding) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _loading ? null : _fundWallet,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_card_outlined, size: 18),
                  label: const Text('Deposit to wallet'),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryColorBlack,
                      ),
                      child: Text(
                        _busy
                            ? 'Processing…'
                            : needsFunding
                                ? 'Pay from wallet'
                                : 'Pay now',
                      ),
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
    this.labelColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor ?? Colors.white70, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}