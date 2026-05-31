import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/products_api.dart';
import '../auth/auth_controller.dart';
import '../models/product_models.dart';
import '../theme/app_colors.dart';

class _GalleryEntry {
  _GalleryEntry(this.file, this.bytes);
  final XFile file;
  final Uint8List bytes;
}

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  List<CatalogProductType> _types = [];
  String? _typesErr;

  String _selectedTypeId = '';
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  XFile? _bannerFile;
  Uint8List? _bannerBytes;
  final List<_GalleryEntry> _galleryEntries = [];
  final Map<String, dynamic> _attributes = {};
  String? _submitErr;
  bool _submitting = false;

  CatalogProductType? get _selectedType {
    for (final t in _types) {
      if (t.id == _selectedTypeId) return t;
    }
    return null;
  }

  List<ProductTypeFieldDef> get _fieldDefs =>
      _selectedType?.fieldDefinitions ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTypes());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final rows = await fetchCatalogProductTypes(token);
      if (mounted) {
        setState(() {
          _types = rows;
          _typesErr = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _typesErr = errorMessage(e));
    }
  }

  void _onTypeChanged(String? id) {
    final nextId = id ?? '';
    CatalogProductType? sel;
    for (final x in _types) {
      if (x.id == nextId) {
        sel = x;
        break;
      }
    }
    setState(() {
      _selectedTypeId = nextId;
      _attributes.clear();
      if (sel != null) {
        for (final d in sel.fieldDefinitions) {
          if (d.valueType == 'boolean') _attributes[d.name] = false;
        }
      }
    });
  }

  Map<String, dynamic> _cleanAttributes() {
    final out = <String, dynamic>{};
    for (final d in _fieldDefs) {
      final v = _attributes[d.name];
      if (v == null) continue;
      if (v is String && v.trim().isEmpty && !d.required) continue;
      out[d.name] = v;
    }
    return out;
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

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _bannerFile = f;
      _bannerBytes = bytes;
      _submitErr = null;
    });
  }

  Future<void> _pickGalleryImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;
    final entries = <_GalleryEntry>[];
    for (final f in files) {
      entries.add(_GalleryEntry(f, await f.readAsBytes()));
    }
    setState(() {
      _galleryEntries.addAll(entries);
      _submitErr = null;
    });
  }

  void _clearGallery() {
    setState(() => _galleryEntries.clear());
  }

  Future<void> _pickAttrImage(String fieldName) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      _submitErr = null;
    });
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

  Future<void> _submitCreate(String visibility) async {
    final token = context.read<AuthController>().token;
    final banner = _bannerFile;
    final bannerBytes = _bannerBytes;
    if (token == null) return;
    if (_selectedTypeId.isEmpty || banner == null || bannerBytes == null) {
      setState(() => _submitErr = 'Choose a category and add a cover photo.');
      return;
    }
    if (_galleryEntries.isEmpty) {
      setState(() => _submitErr = 'Add at least one gallery photo.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitErr = null;
    });
    try {
      final bannerCt = await _guessMime(banner);
      final gallery =
          <({List<int> bytes, String filename, String contentType})>[];
      for (final e in _galleryEntries) {
        final ct = await _guessMime(e.file);
        gallery.add((bytes: e.bytes, filename: e.file.name, contentType: ct));
      }
      await createProductComplete(
        token,
        productTypeId: _selectedTypeId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        attributes: _cleanAttributes(),
        visibility: visibility,
        bannerBytes: bannerBytes.toList(),
        bannerFilename: banner.name,
        bannerContentType: bannerCt,
        gallery: gallery,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              visibility == 'DRAFT' ? 'Draft saved.' : 'Product published.',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _submitErr = errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _memoryThumb(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        !_submitting &&
        _selectedTypeId.isNotEmpty &&
        _bannerFile != null &&
        _bannerBytes != null &&
        _galleryEntries.isNotEmpty &&
        _nameCtrl.text.trim().isNotEmpty &&
        _descCtrl.text.trim().isNotEmpty &&
        _priceCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New listing'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_typesErr != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _typesErr!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                  ),
                ),
              ),
            ),
          DropdownButtonFormField<String>(
            value: _selectedTypeId.isEmpty ? null : _selectedTypeId,
            decoration: const InputDecoration(labelText: 'Category'),
            hint: const Text('Choose…'),
            items: _types
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: _onTypeChanged,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Listing name',
              hintText:
                  'Short title — shown in lists and when picking a product',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price'),
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
          const SizedBox(height: 24),
          Text(
            'Cover photo',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _bannerBytes == null
                  ? InkWell(
                      onTap: _pickBanner,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add cover',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_bannerBytes!, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onPressed: _pickBanner,
                                child: const Text('Change'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  foregroundColor: Colors.red.shade800,
                                ),
                                onPressed: () => setState(() {
                                  _bannerFile = null;
                                  _bannerBytes = null;
                                }),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'More photos',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_galleryEntries.isNotEmpty)
                TextButton(
                  onPressed: _clearGallery,
                  child: Text(
                    'Clear',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Material(
                  color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _pickGalleryImages,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: Icon(
                        Icons.add,
                        color: AppColors.primaryColorBlack,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ..._galleryEntries.asMap().entries.map((e) {
                  final i = e.key;
                  final entry = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        _memoryThumb(entry.bytes),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  setState(() => _galleryEntries.removeAt(i)),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          if (_galleryEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Add at least one more photo.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          _buildDynamicFields(),
          if (_submitErr != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _submitErr!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canSubmit ? () => _submitCreate('DRAFT') : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColorBlack,
                    side: BorderSide(
                      color: AppColors.primaryColorBlack.withValues(alpha: 0.35),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_submitting ? 'Saving…' : 'Save draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canSubmit
                      ? () => _submitCreate('PUBLISHED')
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryColorBlack,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(_submitting ? 'Publishing…' : 'Publish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFields() {
    if (_fieldDefs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          'Extra details',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._fieldDefs.map(_fieldWidget),
      ],
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
    if (d.valueType == 'text') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: '$label${d.required ? ' *' : ''}',
          ),
          onChanged: (v) => setState(() => _attributes[id] = v),
        ),
      );
    }
    if (d.valueType == 'number') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '$label${d.required ? ' *' : ''}',
          ),
          onChanged: (v) {
            if (v.isEmpty) {
              setState(() => _attributes.remove(id));
              return;
            }
            final n = num.tryParse(v);
            if (n != null) setState(() => _attributes[id] = n);
          },
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
                decoration: InputDecoration(
                  labelText: '$label${d.required ? ' *' : ''}',
                ),
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
                  setState(
                    () => _attributes[id] = d0.toUtc().toIso8601String(),
                  );
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
            Text(
              '$label${d.required ? ' *' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
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
                      child: Text(
                        s,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
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
        decoration: InputDecoration(
          labelText: '$label${d.required ? ' *' : ''}',
        ),
        keyboardType: d.valueType == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        onChanged: (v) => setState(() => _attributes[id] = v),
      ),
    );
  }
}
