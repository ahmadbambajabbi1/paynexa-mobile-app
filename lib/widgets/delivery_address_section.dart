import 'package:flutter/material.dart';

import '../api/users_api.dart' as users_api;
import '../theme/app_colors.dart';

class DeliveryFormValues {
  DeliveryFormValues({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.stateRegion,
    required this.postalCode,
    required this.country,
    this.deliveryInstructions = '',
  });

  final String fullName;
  final String phone;
  final String email;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String stateRegion;
  final String postalCode;
  final String country;
  final String deliveryInstructions;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'email': email,
    'addressLine1': addressLine1,
    if (addressLine2.trim().isNotEmpty) 'addressLine2': addressLine2.trim(),
    'city': city,
    'stateRegion': stateRegion,
    'postalCode': postalCode,
    'country': country,
    if (deliveryInstructions.trim().isNotEmpty) 'deliveryInstructions': deliveryInstructions.trim(),
  };

  static DeliveryFormValues fromAddress(users_api.DeliveryAddress row) => DeliveryFormValues(
    fullName: row.fullName,
    phone: row.phone,
    email: row.email,
    addressLine1: row.addressLine1,
    addressLine2: row.addressLine2 ?? '',
    city: row.city,
    stateRegion: row.stateRegion,
    postalCode: row.postalCode,
    country: row.country,
    deliveryInstructions: row.deliveryInstructions ?? '',
  );

  List<String> displayLines() {
    final lines = <String>[
      fullName,
      phone,
      email,
      addressLine1,
      if (addressLine2.trim().isNotEmpty) addressLine2.trim(),
      '$city, $stateRegion $postalCode',
      country,
    ];
    if (deliveryInstructions.trim().isNotEmpty) {
      lines.add('Instructions: ${deliveryInstructions.trim()}');
    }
    return lines;
  }
}

class DeliveryAddressSection extends StatefulWidget {
  const DeliveryAddressSection({
    super.key,
    required this.token,
    required this.confirmed,
    required this.onConfirm,
    required this.onClear,
  });

  final String token;
  final DeliveryFormValues? confirmed;
  final Future<void> Function(DeliveryFormValues values) onConfirm;
  final VoidCallback onClear;

  @override
  State<DeliveryAddressSection> createState() => _DeliveryAddressSectionState();
}

class _DeliveryAddressSectionState extends State<DeliveryAddressSection> {
  List<users_api.DeliveryAddress> _addresses = [];
  bool _loading = true;
  bool _busy = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await users_api.listDeliveryAddresses(widget.token);
      if (!mounted) return;
      setState(() => _addresses = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _addresses = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useSaved(users_api.DeliveryAddress row) async {
    setState(() {
      _busy = true;
      _selectedId = row.id;
    });
    try {
      await widget.onConfirm(DeliveryFormValues.fromAddress(row));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm() async {
    final saved = await showModalBottomSheet<DeliveryFormValues>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DeliveryAddressFormSheet(
        isFirstAddress: _addresses.isEmpty,
        onSave: (values, label) async {
          await users_api.createDeliveryAddress(
            widget.token,
            label: label,
            fullName: values.fullName,
            phone: values.phone,
            email: values.email,
            addressLine1: values.addressLine1,
            addressLine2: values.addressLine2,
            city: values.city,
            stateRegion: values.stateRegion,
            postalCode: values.postalCode,
            country: values.country,
            deliveryInstructions: values.deliveryInstructions,
            isDefault: _addresses.isEmpty,
          );
          if (ctx.mounted) Navigator.of(ctx).pop(values);
        },
      ),
    );
    if (!mounted || saved == null) return;
    await _load();
    await widget.onConfirm(saved);
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = widget.confirmed;
    if (confirmed != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery address',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...confirmed.displayLines().map(
                        (line) => Text(
                          line,
                          style: TextStyle(color: Colors.green.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onClear,
                  child: Text('Change', style: TextStyle(color: Colors.green.shade900)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Delivery required',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a saved address or add a new one before paying.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_loading)
            Text('Loading saved addresses…', style: TextStyle(color: Colors.grey.shade500))
          else
            ..._addresses.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: _selectedId == row.id
                      ? AppColors.primaryColorBlack.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _busy ? null : () => _useSaved(row),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedId == row.id
                              ? AppColors.primaryColorBlack
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label?.trim().isNotEmpty == true ? row.label! : row.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${row.addressLine1}, ${row.city}, ${row.country}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _openForm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryColorBlack,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('+ Add delivery address'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryAddressFormSheet extends StatefulWidget {
  const _DeliveryAddressFormSheet({
    required this.isFirstAddress,
    required this.onSave,
  });

  final bool isFirstAddress;
  final Future<void> Function(DeliveryFormValues values, String label) onSave;

  @override
  State<_DeliveryAddressFormSheet> createState() => _DeliveryAddressFormSheetState();
}

class _DeliveryAddressFormSheetState extends State<_DeliveryAddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController();
  final _instructions = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _country.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final values = DeliveryFormValues(
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        addressLine1: _line1.text.trim(),
        addressLine2: _line2.text.trim(),
        city: _city.text.trim(),
        stateRegion: _state.text.trim(),
        postalCode: _postal.text.trim(),
        country: _country.text.trim(),
        deliveryInstructions: _instructions.text.trim(),
      );
      await widget.onSave(values, _label.text.trim());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New delivery address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(controller: _label, decoration: const InputDecoration(labelText: 'Label (optional)')),
              const SizedBox(height: 8),
              TextFormField(controller: _fullName, decoration: const InputDecoration(labelText: 'Full name'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _line1, decoration: const InputDecoration(labelText: 'Address line 1'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _line2, decoration: const InputDecoration(labelText: 'Address line 2')),
              const SizedBox(height: 8),
              TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State / region'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _postal, decoration: const InputDecoration(labelText: 'Postal code'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _country, decoration: const InputDecoration(labelText: 'Country'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _instructions, decoration: const InputDecoration(labelText: 'Delivery instructions'), maxLines: 3),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryColorBlack,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_busy ? 'Saving…' : 'Save & use for this order'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
