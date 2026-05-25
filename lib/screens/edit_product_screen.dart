import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/products_api.dart';
import '../auth/auth_controller.dart';
import '../models/product_models.dart';
import '../theme/app_colors.dart';

class EditProductScreen extends StatefulWidget {
  const EditProductScreen({super.key, required this.initial});

  final ProductRow initial;

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  final Map<String, TextEditingController> _attrText = {};
  final Map<String, dynamic> _attributes = {};
  String? _submitErr;
  bool _submitting = false;

  List<ProductTypeFieldDef> get _fieldDefs => widget.initial.productType.fieldDefinitions;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _descCtrl = TextEditingController(text: widget.initial.description);
    _attributes.addAll(Map<String, dynamic>.from(widget.initial.attributes));
    for (final d in _fieldDefs) {
      if (d.valueType == 'text') {
        _attrText[d.name] = TextEditingController(text: '${_attributes[d.name] ?? ''}');
      }
      if (d.valueType == 'number') {
        _attrText[d.name] = TextEditingController(
          text: _attributes[d.name] != null ? '${_attributes[d.name]}' : '',
        );
      }
      if (d.valueType == 'string' || d.valueType == 'email') {
        _attrText[d.name] = TextEditingController(text: '${_attributes[d.name] ?? ''}');
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _attrText.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _mergedAttributes() {
    final out = Map<String, dynamic>.from(_attributes);
    for (final d in _fieldDefs) {
      if (d.valueType == 'text' || d.valueType == 'string' || d.valueType == 'email') {
        out[d.name] = _attrText[d.name]?.text ?? '';
      }
      if (d.valueType == 'number') {
        final t = _attrText[d.name]?.text ?? '';
        if (t.isEmpty) {
          out.remove(d.name);
        } else {
          final n = num.tryParse(t);
          if (n != null) out[d.name] = n;
        }
      }
    }
    return out;
  }

  Map<String, dynamic> _cleanAttributes() {
    final raw = _mergedAttributes();
    final out = <String, dynamic>{};
    for (final d in _fieldDefs) {
      final v = raw[d.name];
      if (v == null) continue;
      if (v is String && v.trim().isEmpty && !d.required) continue;
      out[d.name] = v;
    }
    return out;
  }

  Future<void> _pickAttrImage(String fieldName) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    try {
      final f = files.first;
      final bytes = await f.readAsBytes();
      final ct = await _guessMime(f);
      final key = await uploadProductImageFromBytes(token, bytes, ct, f.name);
      setState(() => _attributes[fieldName] = key);
    } catch (e) {
      setState(() => _submitErr = errorMessage(e));
    }
  }

  Future<String> _guessMime(XFile f) async {
    final m = f.mimeType;
    if (m != null &&
        m.isNotEmpty &&
        m.toLowerCase() != 'application/octet-stream') {
      return m;
    }
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.heic')) return 'image/heic';
    if (n.endsWith('.heif')) return 'image/heif';
    if (n.endsWith('.bmp')) return 'image/bmp';
    if (n.endsWith('.tif') || n.endsWith('.tiff')) return 'image/tiff';
    if (n.endsWith('.avif')) return 'image/avif';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.jfif')) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _submitErr = 'Listing name is required.');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _submitErr = 'Description is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitErr = null;
    });
    try {
      await updateProductDetails(
        token,
        widget.initial.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        attributes: _cleanAttributes(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _submitErr = errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameCtrl.text.trim().isNotEmpty && _descCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit details'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.initial.productType.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.gambianBlue,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Photos and cover are managed on the product screen.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Listing name',
              hintText: 'Short title for lists and transaction picks',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ..._fieldDefs.map(_fieldWidget),
          if (_submitErr != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_submitErr!, style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSubmit && !_submitting ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gambianBlue,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_submitting ? 'Saving…' : 'Save details'),
          ),
        ],
      ),
    );
  }

  Widget _fieldWidget(ProductTypeFieldDef d) {
    final label = d.label ?? d.name;
    final id = d.name;
    if (d.valueType == 'boolean') {
      return CheckboxListTile(
        value: _attributes[id] == true,
        onChanged: (v) => setState(() => _attributes[id] = v ?? false),
        title: Text('$label${d.required ? ' *' : ''}'),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }
    if (d.valueType == 'text' && _attrText[id] != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _attrText[id],
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: '$label${d.required ? ' *' : ''}'),
        ),
      );
    }
    if (d.valueType == 'number' && _attrText[id] != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _attrText[id],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '$label${d.required ? ' *' : ''}'),
        ),
      );
    }
    if ((d.valueType == 'string' || d.valueType == 'email') && _attrText[id] != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _attrText[id],
          keyboardType: d.valueType == 'email' ? TextInputType.emailAddress : TextInputType.text,
          decoration: InputDecoration(labelText: '$label${d.required ? ' *' : ''}'),
        ),
      );
    }
    if (d.valueType == 'date') {
      final cur = _attributes[id];
      final display = cur is String ? cur : '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(labelText: '$label${d.required ? ' *' : ''}'),
                child: Text(display.isEmpty ? 'Pick date' : display),
              ),
            ),
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final d0 = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (d0 != null) {
                  setState(() => _attributes[id] = d0.toUtc().toIso8601String());
                }
              },
              child: const Text('Choose'),
            ),
          ],
        ),
      );
    }
    if (d.valueType == 'image' || d.valueType == 'url') {
      final cur = _attributes[id];
      final s = cur is String ? cur : '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label${d.required ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: () => _pickAttrImage(id),
                  child: const Text('Upload'),
                ),
                if (s.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: InputDecoration(labelText: '$label${d.required ? ' *' : ''}'),
        keyboardType: d.valueType == 'email' ? TextInputType.emailAddress : TextInputType.text,
        onChanged: (v) => setState(() => _attributes[id] = v),
      ),
    );
  }
}
