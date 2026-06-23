import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/escrow_api.dart' as escrow;
import '../api/service_marketplace_api.dart' as sm;
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import 'wallet_deposit_sheet.dart';

class BookingPaymentBreakdown {
  const BookingPaymentBreakdown({
    required this.serviceAmount,
    required this.customerPlatformFee,
    required this.providerPlatformFee,
    required this.totalDueFromCustomer,
  });

  final double serviceAmount;
  final double customerPlatformFee;
  final double providerPlatformFee;
  final double totalDueFromCustomer;

  static BookingPaymentBreakdown? fromJson(Object? v) {
    if (v is! Map) return null;
    double n(Object? x) => x is num ? x.toDouble() : double.tryParse('${x ?? ''}') ?? 0;
    final total = n(v['totalDueFromCustomer']);
    if (total <= 0) return null;
    return BookingPaymentBreakdown(
      serviceAmount: n(v['serviceAmount']),
      customerPlatformFee: n(v['customerPlatformFee']),
      providerPlatformFee: n(v['providerPlatformFee']),
      totalDueFromCustomer: total,
    );
  }
}

Future<bool> showMarketplaceBookingPaymentSheet({
  required BuildContext context,
  required String bookingId,
  required String providerUserId,
  required double amount,
  BookingPaymentBreakdown? breakdown,
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MarketplaceBookingPaymentSheet(
      bookingId: bookingId,
      providerUserId: providerUserId,
      amount: amount,
      breakdown: breakdown,
    ),
  );
  return res == true;
}

class _MarketplaceBookingPaymentSheet extends StatefulWidget {
  const _MarketplaceBookingPaymentSheet({
    required this.bookingId,
    required this.providerUserId,
    required this.amount,
    required this.breakdown,
  });

  final String bookingId;
  final String providerUserId;
  final double amount;
  final BookingPaymentBreakdown? breakdown;

  @override
  State<_MarketplaceBookingPaymentSheet> createState() => _MarketplaceBookingPaymentSheetState();
}

class _MarketplaceBookingPaymentSheetState extends State<_MarketplaceBookingPaymentSheet> {
  bool _loading = true;
  bool _busy = false;
  int _modeIndex = 0; // 0 wallet, 1 card
  String _walletBalance = '0';
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
      clientRequestIdPrefix: 'booking-deposit-${widget.bookingId}',
      depositReturnContext: 'booking',
      depositReturnId: widget.bookingId,
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
      await escrow.payMarketplaceServiceBooking(
        token,
        bookingId: widget.bookingId,
        providerUserId: widget.providerUserId,
      );
      await sm.updateBookingState(
        token: token,
        bookingId: widget.bookingId,
        action: 'MARK_FUNDED',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        clientRequestId: 'booking-deposit-${widget.bookingId}',
      );
      if (!mounted) return;
      final credited = deposit['credited'] == true;
      final status = (deposit['status'] ?? '').toString().toUpperCase();
      if (!credited && status != 'SUCCEEDED') {
        throw Exception('Card payment is $status. Please try again or use Wallet.');
      }

      await escrow.payMarketplaceServiceBooking(
        token,
        bookingId: widget.bookingId,
        providerUserId: widget.providerUserId,
      );
      await sm.updateBookingState(
        token: token,
        bookingId: widget.bookingId,
        action: 'MARK_FUNDED',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Complete payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Total due: D${widget.amount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              if (widget.breakdown != null) ...[
                const SizedBox(height: 10),
                _BreakdownCard(b: widget.breakdown!),
              ],
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
                    value: 'D$_walletBalance',
                    valueColor: canWallet ? AppColors.gambianGreen : AppColors.gambianRed,
                  ),
                  if (!canWallet) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Amount needed',
                      value: 'D${_deficit.toStringAsFixed(2)}',
                      valueColor: Colors.orange.shade900,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Insufficient wallet balance. Deposit here or pay with card.',
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
                      decoration: const InputDecoration(
                        labelText: 'Saved card',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'This charges your card, tops up your wallet for this amount, then pays the provider in one flow.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],

              if (needsFunding) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _loading ? null : _fundWallet,
                  icon: const Icon(Icons.add_card_outlined, size: 18),
                  label: const Text('Deposit to wallet'),
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
                          : (_modeIndex == 0
                              ? (canWallet ? _payWithWallet : null)
                              : (hasCards ? _payWithCard : null)),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColorBlack),
                      child: Text(_busy ? 'Working…' : 'Pay and confirm'),
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

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.b});
  final BookingPaymentBreakdown b;

  @override
  Widget build(BuildContext context) {
    final hasFee = b.customerPlatformFee > 0 || b.providerPlatformFee > 0;
    if (!hasFee) return const SizedBox.shrink();
    // Customer checkout: show what they pay only (not provider-side platform fee).
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _kv('Service price', 'D${b.serviceAmount.toStringAsFixed(2)}'),
          if (b.customerPlatformFee > 0)
            _kv('Customer fee', 'D${b.customerPlatformFee.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }
}

