import 'dart:async';
import 'package:flutter/material.dart';

import '../api/api_error.dart';
import '../api/products_api.dart';
import '../api/transactions_api.dart';
import '../api/users_api.dart';
import '../config/constants.dart';
import '../models/product_models.dart';
import '../theme/app_colors.dart';

Future<void> showCreateTransactionSheet({
  required BuildContext context,
  required String token,
  required String selfId,
  required void Function(String transactionId) onCreated,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CreateTransactionPage(
        token: token,
        selfId: selfId,
        onCreated: onCreated,
      ),
    ),
  );
}

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({
    super.key,
    required this.token,
    required this.selfId,
    required this.onCreated,
  });

  final String token;
  final String selfId;
  final void Function(String transactionId) onCreated;

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  String _flow = 'public';
  bool _busy = false;
  String? _err;

  // Escrow
  final _buyerCtrl = TextEditingController();
  Timer? _debounce;
  List<ProductRow> _products = [];
  String _productId = '';
  LookupUserResult? _buyer;
  bool _searching = false;
  String? _lookupMsg;

  // Public
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _deliveryNeeded = false;

  @override
  void initState() {
    super.initState();
    _buyerCtrl.addListener(_onBuyerChanged);
    _qtyCtrl.addListener(_onPublicCalcChanged);
    _priceCtrl.addListener(_onPublicCalcChanged);
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    _buyerCtrl.removeListener(_onBuyerChanged);
    _qtyCtrl.removeListener(_onPublicCalcChanged);
    _priceCtrl.removeListener(_onPublicCalcChanged);
    _debounce?.cancel();
    _buyerCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onPublicCalcChanged() => setState(() {});

  Future<void> _loadProducts() async {
    try {
      final res = await listMyProducts(widget.token, 1, 100);
      if (!mounted) return;
      setState(() {
        _products = res.items;
        _productId = res.items.isNotEmpty ? res.items.first.id : '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _products = []; _productId = ''; });
    }
  }

  void _onBuyerChanged() {
    _debounce?.cancel();
    final q = _buyerCtrl.text.trim();
    if (q.length < 3) {
      setState(() { _buyer = null; _lookupMsg = null; _searching = false; });
      return;
    }
    setState(() { _buyer = null; _lookupMsg = null; _searching = true; });
    _debounce = Timer(
      const Duration(milliseconds: 420),
      () => unawaited(_lookupBuyer()),
    );
  }

  Future<void> _lookupBuyer() async {
    try {
      final found = await lookupUserByQuery(widget.token, _buyerCtrl.text.trim());
      if (!mounted) return;
      if (found.userId == widget.selfId) {
        setState(() { _lookupMsg = 'Buyer must be a different user.'; _buyer = null; _searching = false; });
        return;
      }
      setState(() { _buyer = found; _lookupMsg = null; _searching = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _buyer = null; _lookupMsg = 'No registered buyer matches that email or phone.'; _searching = false; });
    }
  }

  Future<void> _submitEscrow() async {
    setState(() { _busy = true; _err = null; });
    try {
      if (_buyer == null) { setState(() => _err = 'Enter a registered buyer by email or phone.'); return; }
      if (_productId.isEmpty) { setState(() => _err = 'Select one of your products first.'); return; }
      final res = await createEscrowTransaction(
        widget.token,
        createdByUserId: widget.selfId,
        counterpartyId: _buyer!.userId,
        productId: _productId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated(res.transactionId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPublic() async {
    setState(() { _busy = true; _err = null; });
    try {
      final title = _titleCtrl.text.trim();
      if (title.isEmpty) { setState(() => _err = 'Item title is required.'); return; }
      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
      if (qty < 1) { setState(() => _err = 'Quantity must be at least 1.'); return; }
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
      if (price <= 0) { setState(() => _err = 'Unit price must be greater than zero.'); return; }
      final res = await createPublicTransaction(
        widget.token,
        createdByUserId: widget.selfId,
        itemTitle: title,
        itemDescription: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        quantity: qty,
        unitPrice: price,
        deliveryNeeded: _deliveryNeeded,
        sellerNote: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated(res.transactionId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // backgroundColor: AppColors.primaryColorBlack,
        // foregroundColor: Colors.white,
        title: const Text(
          'New Transaction',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, ),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Flow switcher ──────────────────────────────────────
          // Container(
          //   color: AppColors.primaryColorBlack,
          //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          //   child: Container(
          //     padding: const EdgeInsets.all(4),
          //     decoration: BoxDecoration(
          //       color: Colors.white.withValues(alpha: 0.15),
          //       borderRadius: BorderRadius.circular(16),
          //     ),
          //     // child: Row(
          //     //   children: [
          //     //     Expanded(
          //     //       child: _flowButton(
          //     //         label: 'Shareable Link',
          //     //         icon: Icons.link_rounded,
          //     //         isActive: _flow == 'public',
          //     //         onTap: () => setState(() { _flow = 'public'; _err = null; }),
          //     //       ),
          //     //     ),
          //     //     Expanded(
          //     //       child: _flowButton(
          //     //         label: 'Private Deal',
          //     //         icon: Icons.people_outline_rounded,
          //     //         isActive: _flow == 'escrow',
          //     //         onTap: () => setState(() { _flow = 'escrow'; _err = null; }),
          //     //       ),
          //     //     ),
          //     //   ],
          //     // ),
          //   ),
          // ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                if (_flow == 'public') ..._buildPublicForm()
                else ..._buildEscrowForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primaryColorBlack : Colors.white70),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isActive ? AppColors.primaryColorBlack : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPublicForm() {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final total = qty * price;

    return [
      // ── Section header ───────────────────────────────────────
      Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.link_rounded, color: AppColors.primaryColorBlack, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shareable Sale Link',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create a payment link anyone can use to buy from you securely.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),

      _inputLabel('Item or Service Title'),
      _inputField(_titleCtrl, 'What are you selling?'),
      const SizedBox(height: 16),

      _inputLabel('Description (Optional)'),
      _inputField(_descCtrl, 'Describe the condition, specifications, or terms of sale...', minLines: 4, maxLines: 4),
      const SizedBox(height: 16),

      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputLabel('Quantity'),
                _inputField(_qtyCtrl, '1', keyboardType: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputLabel('Unit Price (GMD)'),
                _inputField(_priceCtrl, '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Delivery toggle ──────────────────────────────────────
      GestureDetector(
        onTap: () => setState(() => _deliveryNeeded = !_deliveryNeeded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _deliveryNeeded
                ? AppColors.primaryColorBlack.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _deliveryNeeded
                  ? AppColors.primaryColorBlack.withValues(alpha: 0.3)
                  : const Color(0xFFE8EBF2),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _deliveryNeeded ? AppColors.primaryColorBlack : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _deliveryNeeded ? AppColors.primaryColorBlack : const Color(0xFFBCC4D8),
                    width: 1.5,
                  ),
                ),
                child: _deliveryNeeded
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Track Delivery / Shipment',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Funds remain locked until delivery is confirmed.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.local_shipping_outlined,
                color: _deliveryNeeded ? AppColors.primaryColorBlack : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      _inputLabel('Seller Note to Buyer (Optional)'),
      _inputField(_noteCtrl, 'Message shown to buyer on checkout...', minLines: 4, maxLines: 4),
      const SizedBox(height: 24),

      // ── Summary ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primaryColorBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryColorBlack.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            _summaryRow('Quantity', '$qty'),
            _summaryRow('Unit price', '$kCurrencyPrefix${price.toStringAsFixed(2)}'),
            const Divider(height: 20),
            _summaryRow('Buyer Pays (Total)', '$kCurrencyPrefix${total.toStringAsFixed(2)}', strong: true),
          ],
        ),
      ),

      if (_err != null) ...[const SizedBox(height: 16), _errorBox(_err!)],
      const SizedBox(height: 24),

      FilledButton(
        onPressed: _busy ? null : _submitPublic,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColorBlack,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 0),
        ),
        child: Text(
          _busy ? 'Generating Link...' : 'Create Shareable Link',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    ];
  }

  List<Widget> _buildEscrowForm() {
    ProductRow? selected;
    for (final p in _products) {
      if (p.id == _productId) selected = p;
    }
    final amount = double.tryParse(selected?.price ?? '') ?? 0.0;
    final fee = amount * kEscrowFeePercent / 100;

    return [
      // ── Section header ───────────────────────────────────────
      Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.primaryColorBlack, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private Escrow Deal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invite a specific registered buyer to a secure escrow room.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),

      _inputLabel('Product you own'),
      DropdownButtonFormField<String>(
        value: _productId.isEmpty ? null : _productId,
        decoration: _inputDec('Select a product'),
        dropdownColor: Colors.white,
        items: _products
            .map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(productDisplayName(p), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _productId = v ?? ''),
      ),
      if (_products.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text('Create a catalog product before launching escrow.', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
        ),
      const SizedBox(height: 16),

      _inputLabel('Buyer Email or Phone'),
      _inputField(_buyerCtrl, 'Search registered buyer'),
      if (_searching)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text('Searching...', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ),
      if (_lookupMsg != null && !_searching)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(_lookupMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
        ),
      if (_buyer != null && !_searching) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryColorBlack.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryColorBlack.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryColorBlack.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.primaryColorBlack, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _buyer!.displayName ?? 'Registered buyer',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      [_buyer!.email, if (_buyer!.phone.trim().isNotEmpty) _buyer!.phone].whereType<String>().join(' · '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),

      // ── Summary ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primaryColorBlack.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryColorBlack.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            _summaryRow('Product amount', '$kCurrencyPrefix${selected?.price ?? '0.00'}'),
            _summaryRow('Escrow fee (${kEscrowFeePercent}%)', '$kCurrencyPrefix${fee.toStringAsFixed(2)}'),
            const Divider(height: 20),
            _summaryRow('Total protected', '$kCurrencyPrefix${(amount + fee).toStringAsFixed(2)}', strong: true),
          ],
        ),
      ),

      if (_err != null) ...[const SizedBox(height: 16), _errorBox(_err!)],
      const SizedBox(height: 24),

      FilledButton(
        onPressed: _busy || _products.isEmpty ? null : _submitEscrow,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColorBlack,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 0),
        ),
        child: Text(
          _busy ? 'Creating Escrow...' : 'Create Private Escrow',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    ];
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
      decoration: _inputDec(hint),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8EBF2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8EBF2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryColorBlack, width: 1.5),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String k, String v, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                fontSize: strong ? 14 : 13,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: strong ? const Color(0xFF0F172A) : Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: strong ? 16 : 14,
              color: strong ? AppColors.primaryColorBlack : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}