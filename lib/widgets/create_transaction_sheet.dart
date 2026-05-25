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
  // Flow selector: 'public' or 'escrow'
  String _flow = 'public';

  // Common state
  bool _busy = false;
  String? _err;

  // Escrow flow state
  final _buyerCtrl = TextEditingController();
  Timer? _debounce;
  List<ProductRow> _products = [];
  String _productId = '';
  LookupUserResult? _buyer;
  bool _searching = false;
  String? _lookupMsg;

  // Public flow state
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

  void _onPublicCalcChanged() {
    setState(() {});
  }

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
      setState(() {
        _products = [];
        _productId = '';
      });
    }
  }

  void _onBuyerChanged() {
    _debounce?.cancel();
    final q = _buyerCtrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _buyer = null;
        _lookupMsg = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _buyer = null;
      _lookupMsg = null;
      _searching = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 420),
      () => unawaited(_lookupBuyer()),
    );
  }

  Future<void> _lookupBuyer() async {
    try {
      final found = await lookupUserByQuery(
        widget.token,
        _buyerCtrl.text.trim(),
      );
      if (!mounted) return;
      if (found.userId == widget.selfId) {
        setState(() {
          _lookupMsg = 'Buyer must be a different user.';
          _buyer = null;
          _searching = false;
        });
        return;
      }
      setState(() {
        _buyer = found;
        _lookupMsg = null;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buyer = null;
        _lookupMsg = 'No registered buyer matches that email or phone.';
        _searching = false;
      });
    }
  }

  Future<void> _submitEscrow() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (_buyer == null) {
        setState(() => _err = 'Enter a registered buyer by email or phone.');
        return;
      }
      if (_productId.isEmpty) {
        setState(() => _err = 'Select one of your products first.');
        return;
      }
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
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final title = _titleCtrl.text.trim();
      if (title.isEmpty) {
        setState(() => _err = 'Item title is required.');
        return;
      }
      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
      if (qty < 1) {
        setState(() => _err = 'Quantity must be at least 1.');
        return;
      }
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
      if (price <= 0) {
        setState(() => _err = 'Unit price must be greater than zero.');
        return;
      }

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
        title: const Text('New Transaction'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gambianBlue,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Flow Switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _flowButton(
                      label: 'Shareable Link',
                      icon: Icons.link,
                      isActive: _flow == 'public',
                      onTap: () => setState(() {
                        _flow = 'public';
                        _err = null;
                      }),
                    ),
                  ),
                  Expanded(
                    child: _flowButton(
                      label: 'Private Deal',
                      icon: Icons.people_outline,
                      isActive: _flow == 'escrow',
                      onTap: () => setState(() {
                        _flow = 'escrow';
                        _err = null;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  if (_flow == 'public') ..._buildPublicForm() else ..._buildEscrowForm(),
                ],
              ),
            ),
          ],
        ),
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
          color: isActive ? AppColors.gambianBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.gambianBlue.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isActive ? Colors.white : Colors.grey.shade600,
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
      Text(
        'Create Shareable Sale Link',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.gambianBlue,
            ),
      ),
      const SizedBox(height: 4),
      Text(
        'Create a public checkout page link. Anyone with this link can view details and claim to buy this single item/service.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 20),
      _inputLabel('Item or Service Title *'),
      TextField(
        controller: _titleCtrl,
        decoration: _inputDec('What are you selling?'),
        keyboardType: TextInputType.text,
      ),
      const SizedBox(height: 16),
      _inputLabel('Description / Details (Optional)'),
      TextField(
        controller: _descCtrl,
        decoration: _inputDec('Describe the condition, specifications, or terms of sale...'),
        maxLines: 3,
        keyboardType: TextInputType.multiline,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputLabel('Quantity *'),
                TextField(
                  controller: _qtyCtrl,
                  decoration: _inputDec('1'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputLabel('Unit Price (GMD) *'),
                TextField(
                  controller: _priceCtrl,
                  decoration: _inputDec('0.00'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CheckboxListTile(
          value: _deliveryNeeded,
          onChanged: (v) => setState(() => _deliveryNeeded = v ?? false),
          title: const Text(
            'Track Delivery / Shipment',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Funds remain locked in escrow until shipping is tracked and delivered.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          activeColor: AppColors.gambianBlue,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      const SizedBox(height: 16),
      _inputLabel('Seller Note to Buyer (Optional)'),
      TextField(
        controller: _noteCtrl,
        decoration: _inputDec('Message shown to buyer on checkout...'),
        keyboardType: TextInputType.text,
      ),
      const SizedBox(height: 24),
      // Calculation panel
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gambianBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gambianBlue.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            _row('Quantity', '$qty'),
            _row('Unit price', '$kCurrencyPrefix${price.toStringAsFixed(2)}'),
            const Divider(height: 16),
            _row(
              'Buyer Pays (Total)',
              '$kCurrencyPrefix${total.toStringAsFixed(2)}',
              strong: true,
            ),
          ],
        ),
      ),
      if (_err != null) ...[
        const SizedBox(height: 16),
        _errorBox(_err!),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy ? null : _submitPublic,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gambianBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      Text(
        'Create Two-party Escrow',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.gambianBlue,
            ),
      ),
      const SizedBox(height: 4),
      Text(
        'Invite a specific registered buyer to complete this secure transaction. SafeTrade secures payment and release terms.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 20),
      _inputLabel('Product you own *'),
      DropdownButtonFormField<String>(
        value: _productId.isEmpty ? null : _productId,
        decoration: _inputDec('Select a product'),
        items: _products
            .map(
              (p) => DropdownMenuItem(
                value: p.id,
                child: Text(
                  productDisplayName(p),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _productId = v ?? ''),
      ),
      if (_products.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Create a catalog product before launching escrow.',
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ),
      const SizedBox(height: 16),
      _inputLabel('Buyer Email or Phone *'),
      TextField(
        controller: _buyerCtrl,
        decoration: _inputDec('Search registered buyer'),
        keyboardType: TextInputType.text,
      ),
      if (_searching)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Searching...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      if (_lookupMsg != null && !_searching)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            _lookupMsg!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ),
      if (_buyer != null && !_searching)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.gambianBlue, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Buyer found',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.gambianBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _buyer!.displayName ?? 'Registered buyer',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  _buyer!.email,
                  if (_buyer!.phone.trim().isNotEmpty) _buyer!.phone,
                ].whereType<String>().join(' · '),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      // Calculation panel
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gambianBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gambianBlue.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            _row('Product amount', '$kCurrencyPrefix${selected?.price ?? '0.00'}'),
            _row(
              'Escrow protection fee (${kEscrowFeePercent}%)',
              '$kCurrencyPrefix${fee.toStringAsFixed(2)}',
            ),
            const Divider(height: 16),
            _row(
              'Total protected amount',
              '$kCurrencyPrefix${(amount + fee).toStringAsFixed(2)}',
              strong: true,
            ),
          ],
        ),
      ),
      if (_err != null) ...[
        const SizedBox(height: 16),
        _errorBox(_err!),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy || _products.isEmpty ? null : _submitEscrow,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gambianBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gambianBlue, width: 1.5),
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
          Icon(Icons.error_outline, color: Colors.red.shade800, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                k,
                style: TextStyle(
                  color: strong ? AppColors.gambianBlue : Colors.grey.shade600,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                  fontSize: strong ? 14 : 13,
                ),
              ),
            ),
            Text(
              v,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: strong ? AppColors.gambianBlue : Colors.grey.shade900,
                fontSize: strong ? 16 : 14,
              ),
            ),
          ],
        ),
      );
}
// import 'dart:async';
// import 'package:flutter/material.dart';

// import '../api/api_error.dart';
// import '../api/products_api.dart';
// import '../api/transactions_api.dart';
// import '../api/users_api.dart';
// import '../config/constants.dart';
// import '../models/product_models.dart';
// import '../theme/app_colors.dart';

// Future<void> showCreateTransactionSheet({
//   required BuildContext context,
//   required String token,
//   required String selfId,
//   required void Function(String transactionId) onCreated,
// }) {
//   return Navigator.of(context).push<void>(
//     MaterialPageRoute<void>(
//       builder: (_) => CreateTransactionPage(
//         token: token,
//         selfId: selfId,
//         onCreated: onCreated,
//       ),
//     ),
//   );
// }

// class CreateTransactionPage extends StatefulWidget {
//   const CreateTransactionPage({
//     super.key,
//     required this.token,
//     required this.selfId,
//     required this.onCreated,
//   });

//   final String token;
//   final String selfId;
//   final void Function(String transactionId) onCreated;

//   @override
//   State<CreateTransactionPage> createState() => _CreateTransactionPageState();
// }

// class _CreateTransactionPageState extends State<CreateTransactionPage> {
//   String _flow = 'public';
//   bool _busy = false;
//   String? _err;

//   // Escrow
//   final _buyerCtrl = TextEditingController();
//   Timer? _debounce;
//   List<ProductRow> _products = [];
//   String _productId = '';
//   LookupUserResult? _buyer;
//   bool _searching = false;
//   String? _lookupMsg;

//   // Public
//   final _titleCtrl = TextEditingController();
//   final _descCtrl = TextEditingController();
//   final _qtyCtrl = TextEditingController(text: '1');
//   final _priceCtrl = TextEditingController();
//   final _noteCtrl = TextEditingController();
//   bool _deliveryAvailable = false;
//   final _deliveryPriceCtrl = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _buyerCtrl.addListener(_onBuyerChanged);
//     _qtyCtrl.addListener(_recalc);
//     _priceCtrl.addListener(_recalc);
//     _deliveryPriceCtrl.addListener(_recalc);
//     unawaited(_loadProducts());
//   }

//   @override
//   void dispose() {
//     _buyerCtrl.removeListener(_onBuyerChanged);
//     _qtyCtrl.removeListener(_recalc);
//     _priceCtrl.removeListener(_recalc);
//     _deliveryPriceCtrl.removeListener(_recalc);
//     _debounce?.cancel();
//     _buyerCtrl.dispose();
//     _titleCtrl.dispose();
//     _descCtrl.dispose();
//     _qtyCtrl.dispose();
//     _priceCtrl.dispose();
//     _noteCtrl.dispose();
//     _deliveryPriceCtrl.dispose();
//     super.dispose();
//   }

//   void _recalc() => setState(() {});

//   Future<void> _loadProducts() async {
//     try {
//       final res = await listMyProducts(widget.token, 1, 100);
//       if (!mounted) return;
//       setState(() {
//         _products = res.items;
//         _productId = res.items.isNotEmpty ? res.items.first.id : '';
//       });
//     } catch (_) {
//       if (!mounted) return;
//       setState(() {
//         _products = [];
//         _productId = '';
//       });
//     }
//   }

//   void _onBuyerChanged() {
//     _debounce?.cancel();
//     final q = _buyerCtrl.text.trim();
//     if (q.length < 3) {
//       setState(() { _buyer = null; _lookupMsg = null; _searching = false; });
//       return;
//     }
//     setState(() { _buyer = null; _lookupMsg = null; _searching = true; });
//     _debounce = Timer(
//       const Duration(milliseconds: 420),
//       () => unawaited(_lookupBuyer()),
//     );
//   }

//   Future<void> _lookupBuyer() async {
//     try {
//       final found = await lookupUserByQuery(widget.token, _buyerCtrl.text.trim());
//       if (!mounted) return;
//       if (found.userId == widget.selfId) {
//         setState(() { _lookupMsg = 'Buyer must be a different user.'; _buyer = null; _searching = false; });
//         return;
//       }
//       setState(() { _buyer = found; _lookupMsg = null; _searching = false; });
//     } catch (_) {
//       if (!mounted) return;
//       setState(() { _buyer = null; _lookupMsg = 'No registered user matches that email or phone.'; _searching = false; });
//     }
//   }

//   Future<void> _submitEscrow() async {
//     setState(() { _busy = true; _err = null; });
//     try {
//       if (_buyer == null) { setState(() => _err = 'Enter a registered buyer by email or phone.'); return; }
//       if (_productId.isEmpty) { setState(() => _err = 'Select one of your products first.'); return; }
//       final res = await createEscrowTransaction(
//         widget.token,
//         createdByUserId: widget.selfId,
//         counterpartyId: _buyer!.userId,
//         productId: _productId,
//       );
//       if (!mounted) return;
//       Navigator.of(context).pop();
//       widget.onCreated(res.transactionId);
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _err = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   Future<void> _submitPublic() async {
//     setState(() { _busy = true; _err = null; });
//     try {
//       final title = _titleCtrl.text.trim();
//       if (title.isEmpty) { setState(() => _err = 'Item title is required.'); return; }
//       final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
//       if (qty < 1) { setState(() => _err = 'Quantity must be at least 1.'); return; }
//       final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
//       if (price <= 0) { setState(() => _err = 'Price must be greater than zero.'); return; }
//       double? deliveryPrice;
//       if (_deliveryAvailable) {
//         deliveryPrice = double.tryParse(_deliveryPriceCtrl.text.trim());
//         if (deliveryPrice == null || deliveryPrice < 0) {
//           setState(() => _err = 'Enter a valid delivery price (0 or more).');
//           return;
//         }
//       }
//       final res = await createPublicTransaction(
//         widget.token,
//         createdByUserId: widget.selfId,
//         itemTitle: title,
//         itemDescription: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
//         quantity: qty,
//         unitPrice: price,
//         // deliveryAvailable: _deliveryAvailable,
//         deliveryPrice: deliveryPrice,
//         sellerNote: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
//       );
//       if (!mounted) return;
//       Navigator.of(context).pop();
//       widget.onCreated(res.transactionId);
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _err = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFF),
//       appBar: AppBar(
//         backgroundColor: AppColors.gambianBlue,
//         foregroundColor: Colors.white,
//         title: const Text(
//           'New Transaction',
//           style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
//         ),
//         elevation: 0,
//         centerTitle: false,
//       ),
//       body: Column(
//         children: [
//           _FlowPicker(
//             active: _flow,
//             onChanged: (v) => setState(() { _flow = v; _err = null; }),
//           ),
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
//               children: _flow == 'public' ? _buildPublicForm() : _buildEscrowForm(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildPublicForm() {
//     final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
//     final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
//     final deliveryPrice = _deliveryAvailable
//         ? (double.tryParse(_deliveryPriceCtrl.text.trim()) ?? 0.0)
//         : 0.0;
//     final total = qty * price;

//     return [
//       _SectionHeader(
//         title: 'Shareable Sale Link',
//         subtitle: 'Create a payment link anyone can use to buy from you securely.',
//         icon: Icons.link_rounded,
//       ),
//       const SizedBox(height: 20),
//       _Field(label: 'Item or Service Title', hint: 'What are you selling?', controller: _titleCtrl),
//       const SizedBox(height: 14),
//       _Field(
//         label: 'Description',
//         hint: 'Condition, specifications, or sale terms (optional)',
//         controller: _descCtrl,
//         maxLines: 3,
//         required: false,
//       ),
//       const SizedBox(height: 14),
//       Row(
//         children: [
//           Expanded(child: _Field(label: 'Quantity', hint: '1', controller: _qtyCtrl, keyboardType: TextInputType.number)),
//           const SizedBox(width: 12),
//           Expanded(child: _Field(label: 'Unit Price (GMD)', hint: '0.00', controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
//         ],
//       ),
//       const SizedBox(height: 14),

//       // ── Delivery toggle ──
//       _DeliveryToggle(
//         enabled: _deliveryAvailable,
//         onChanged: (v) => setState(() { _deliveryAvailable = v; }),
//       ),
//       if (_deliveryAvailable) ...[
//         const SizedBox(height: 12),
//         _Field(
//           label: 'Delivery Price (GMD)',
//           hint: '0.00 — enter 0 for free delivery',
//           controller: _deliveryPriceCtrl,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//         ),
//       ],
//       const SizedBox(height: 14),
//       _Field(
//         label: 'Note to Buyer',
//         hint: 'Message shown to the buyer at checkout (optional)',
//         controller: _noteCtrl,
//         required: false,
//       ),
//       const SizedBox(height: 20),

//       // ── Summary ──
//       _SummaryCard(rows: [
//         ('Quantity', '$qty'),
//         ('Item price', '$kCurrencyPrefix${price.toStringAsFixed(2)}'),
//         if (_deliveryAvailable)
//           ('Delivery (if buyer selects)', '$kCurrencyPrefix${deliveryPrice.toStringAsFixed(2)}'),
//         ('Buyer pays', '$kCurrencyPrefix${total.toStringAsFixed(2)}', true),
//       ]),
//       if (_err != null) ...[const SizedBox(height: 14), _ErrorBox(message: _err!)],
//       const SizedBox(height: 20),
//       _SubmitButton(
//         busy: _busy,
//         label: 'Create Sale Link',
//         busyLabel: 'Creating…',
//         onPressed: _submitPublic,
//       ),
//     ];
//   }

//   List<Widget> _buildEscrowForm() {
//     ProductRow? selected;
//     for (final p in _products) {
//       if (p.id == _productId) selected = p;
//     }
//     final amount = double.tryParse(selected?.price ?? '') ?? 0.0;
//     final fee = amount * kEscrowFeePercent / 100;

//     return [
//       _SectionHeader(
//         title: 'Private Escrow Deal',
//         subtitle: 'Invite a specific buyer to a secure escrow room.',
//         icon: Icons.shield_outlined,
//       ),
//       const SizedBox(height: 20),
//       _FieldLabel('Your product'),
//       const SizedBox(height: 6),
//       DropdownButtonFormField<String>(
//         value: _productId.isEmpty ? null : _productId,
//         decoration: _dec('Select a product'),
//         items: _products
//             .map((p) => DropdownMenuItem(
//                   value: p.id,
//                   child: Text(productDisplayName(p), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
//                 ))
//             .toList(),
//         onChanged: (v) => setState(() => _productId = v ?? ''),
//       ),
//       if (_products.isEmpty)
//         Padding(
//           padding: const EdgeInsets.only(top: 8, left: 4),
//           child: Text('Create a product in your catalog first.', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
//         ),
//       const SizedBox(height: 14),
//       _Field(label: 'Buyer Email or Phone', hint: 'Search registered buyer', controller: _buyerCtrl),
//       if (_searching)
//         Padding(
//           padding: const EdgeInsets.only(top: 8, left: 4),
//           child: Text('Searching…', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
//         ),
//       if (_lookupMsg != null && !_searching)
//         Padding(
//           padding: const EdgeInsets.only(top: 8, left: 4),
//           child: Text(_lookupMsg!, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
//         ),
//       if (_buyer != null && !_searching) ...[
//         const SizedBox(height: 12),
//         _BuyerFoundCard(buyer: _buyer!),
//       ],
//       const SizedBox(height: 20),
//       _SummaryCard(rows: [
//         ('Product amount', '$kCurrencyPrefix${selected?.price ?? '0.00'}'),
//         ('Escrow fee (${kEscrowFeePercent}%)', '$kCurrencyPrefix${fee.toStringAsFixed(2)}'),
//         ('Total protected', '$kCurrencyPrefix${(amount + fee).toStringAsFixed(2)}', true),
//       ]),
//       if (_err != null) ...[const SizedBox(height: 14), _ErrorBox(message: _err!)],
//       const SizedBox(height: 20),
//       _SubmitButton(
//         busy: _busy || _products.isEmpty,
//         label: 'Create Escrow Deal',
//         busyLabel: 'Creating…',
//         onPressed: _products.isEmpty ? null : _submitEscrow,
//       ),
//     ];
//   }

//   InputDecoration _dec(String hint) => InputDecoration(
//         hintText: hint,
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         filled: true,
//         fillColor: Colors.white,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: const BorderSide(color: AppColors.gambianBlue, width: 1.5),
//         ),
//       );
// }

// // ─── Sub-widgets ──────────────────────────────────────────────────────────────

// class _FlowPicker extends StatelessWidget {
//   const _FlowPicker({required this.active, required this.onChanged});
//   final String active;
//   final ValueChanged<String> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: AppColors.gambianBlue,
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//       child: Container(
//         padding: const EdgeInsets.all(4),
//         decoration: BoxDecoration(
//           color: Colors.white.withValues(alpha: 0.15),
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Row(
//           children: [
//             _Pill(
//               label: 'Shareable Link',
//               icon: Icons.link_rounded,
//               active: active == 'public',
//               onTap: () => onChanged('public'),
//             ),
//             _Pill(
//               label: 'Private Deal',
//               icon: Icons.people_outline_rounded,
//               active: active == 'escrow',
//               onTap: () => onChanged('escrow'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _Pill extends StatelessWidget {
//   const _Pill({required this.label, required this.icon, required this.active, required this.onTap});
//   final String label;
//   final IconData icon;
//   final bool active;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           padding: const EdgeInsets.symmetric(vertical: 11),
//           decoration: BoxDecoration(
//             color: active ? Colors.white : Colors.transparent,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 16, color: active ? AppColors.gambianBlue : Colors.white70),
//               const SizedBox(width: 7),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w800,
//                   color: active ? AppColors.gambianBlue : Colors.white70,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _SectionHeader extends StatelessWidget {
//   const _SectionHeader({required this.title, required this.subtitle, required this.icon});
//   final String title;
//   final String subtitle;
//   final IconData icon;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//             color: AppColors.gambianBlue.withValues(alpha: 0.1),
//             borderRadius: BorderRadius.circular(14),
//           ),
//           child: Icon(icon, color: AppColors.gambianBlue, size: 22),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3)),
//               const SizedBox(height: 2),
//               Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _FieldLabel extends StatelessWidget {
//   const _FieldLabel(this.text, {this.required = true});
//   final String text;
//   final bool required;

//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       required ? text : '$text (optional)',
//       style: TextStyle(
//         fontSize: 12,
//         fontWeight: FontWeight.w700,
//         color: Colors.grey.shade700,
//       ),
//     );
//   }
// }

// class _Field extends StatelessWidget {
//   const _Field({
//     required this.label,
//     required this.hint,
//     required this.controller,
//     this.maxLines = 1,
//     this.keyboardType,
//     this.required = true,
//   });

//   final String label;
//   final String hint;
//   final TextEditingController controller;
//   final int maxLines;
//   final TextInputType? keyboardType;
//   final bool required;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _FieldLabel(label, required: required),
//         const SizedBox(height: 6),
//         TextField(
//           controller: controller,
//           maxLines: maxLines,
//           keyboardType: keyboardType,
//           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//           decoration: InputDecoration(
//             hintText: hint,
//             hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
//             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDDE3F0))),
//             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDDE3F0))),
//             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gambianBlue, width: 1.5)),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _DeliveryToggle extends StatelessWidget {
//   const _DeliveryToggle({required this.enabled, required this.onChanged});
//   final bool enabled;
//   final ValueChanged<bool> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => onChanged(!enabled),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: enabled
//               ? AppColors.gambianBlue.withValues(alpha: 0.06)
//               : Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: enabled ? AppColors.gambianBlue.withValues(alpha: 0.3) : const Color(0xFFDDE3F0),
//           ),
//         ),
//         child: Row(
//           children: [
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               width: 22,
//               height: 22,
//               decoration: BoxDecoration(
//                 color: enabled ? AppColors.gambianBlue : Colors.transparent,
//                 borderRadius: BorderRadius.circular(7),
//                 border: Border.all(
//                   color: enabled ? AppColors.gambianBlue : const Color(0xFFBCC4D8),
//                   width: 1.5,
//                 ),
//               ),
//               child: enabled
//                   ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
//                   : null,
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Offer Delivery',
//                     style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     'Buyers can choose delivery at checkout and provide their address.',
//                     style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(
//               Icons.local_shipping_outlined,
//               color: enabled ? AppColors.gambianBlue : Colors.grey.shade400,
//               size: 20,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _BuyerFoundCard extends StatelessWidget {
//   const _BuyerFoundCard({required this.buyer});
//   final LookupUserResult buyer;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F7FF),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFBFD9FF)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 36,
//             height: 36,
//             decoration: BoxDecoration(
//               color: AppColors.gambianBlue.withValues(alpha: 0.12),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.check_rounded, color: AppColors.gambianBlue, size: 18),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   buyer.displayName ?? 'Registered buyer',
//                   style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
//                 ),
//                 if ((buyer.email?.isNotEmpty ?? false) || (buyer.phone?.trim().isNotEmpty ?? false))
//                   Text(
//                     [buyer.email, if (buyer.phone?.trim().isNotEmpty ?? false) buyer.phone].whereType<String>().join(' · '),
//                     style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SummaryCard extends StatelessWidget {
//   const _SummaryCard({required this.rows});
//   final List<dynamic> rows; // (label, value) or (label, value, bold)

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFEEF0F6)),
//       ),
//       child: Column(
//         children: List.generate(rows.length, (i) {
//           final row = rows[i];
//           final label = row.$1 as String;
//           final value = row.$2 as String;
//           final strong = rows[i] is (String, String, bool) ? (row.$3 as bool) : false;
//           return Column(
//             children: [
//               if (i > 0 && strong) const Divider(height: 16),
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 3),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         label,
//                         style: TextStyle(
//                           fontSize: strong ? 13 : 12,
//                           fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
//                           color: strong ? const Color(0xFF0F172A) : Colors.grey.shade600,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       value,
//                       style: TextStyle(
//                         fontSize: strong ? 16 : 13,
//                         fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
//                         color: strong ? AppColors.gambianBlue : const Color(0xFF0F172A),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           );
//         }),
//       ),
//     );
//   }
// }

// class _SubmitButton extends StatelessWidget {
//   const _SubmitButton({
//     required this.busy,
//     required this.label,
//     required this.busyLabel,
//     required this.onPressed,
//   });

//   final bool busy;
//   final String label;
//   final String busyLabel;
//   final VoidCallback? onPressed;

//   @override
//   Widget build(BuildContext context) {
//     return FilledButton(
//       onPressed: busy ? null : onPressed,
//       style: FilledButton.styleFrom(
//         backgroundColor: AppColors.gambianBlue,
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         minimumSize: const Size(double.infinity, 0),
//       ),
//       child: Text(
//         busy ? busyLabel : label,
//         style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
//       ),
//     );
//   }
// }

// class _ErrorBox extends StatelessWidget {
//   const _ErrorBox({required this.message});
//   final String message;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.red.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.red.shade100),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(message, style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
//           ),
//         ],
//       ),
//     );
//   }
// }