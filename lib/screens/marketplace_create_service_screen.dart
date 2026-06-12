import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../api/service_marketplace_api.dart' as sm;
import '../api/service_marketplace_create_api.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

class MarketplaceCreateServiceScreen extends StatefulWidget {
  const MarketplaceCreateServiceScreen({super.key});

  @override
  State<MarketplaceCreateServiceScreen> createState() =>
      _MarketplaceCreateServiceScreenState();
}

class _MarketplaceCreateServiceScreenState
    extends State<MarketplaceCreateServiceScreen> {
  final _picker = ImagePicker();

  bool _loadingCats = false;
  bool _submitting = false;
  String? _err;

  List<sm.ServiceCategory> _cats = const [];
  String? _categoryId;

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _priceAmount = TextEditingController();

  Uint8List? _coverBytes;
  String? _coverName;
  String _pendingVisibility = 'PUBLISHED';
  String _coverContentType = 'image/jpeg';

  final List<({Uint8List bytes, String name, String contentType})> _gallery =
      [];
  Timer? _locTimer;

  @override
  void initState() {
    super.initState();
    _loadCats();
    _locTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      unawaited(_throttledRenderingPing());
    });
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _title.dispose();
    _description.dispose();
    _priceAmount.dispose();
    super.dispose();
  }

  Future<void> _throttledRenderingPing() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null) return;
    if (!await Permission.locationWhenInUse.isGranted) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      await sm.maybePingRenderingLocation(
        token: token,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {}
  }

  Future<void> _loadCats() async {
    setState(() {
      _loadingCats = true;
      _err = null;
    });
    try {
      final cats = await sm.listServiceCategories();
      setState(() {
        _cats = cats;
        _categoryId ??= cats.isNotEmpty ? cats.first.id : null;
      });
    } catch (e) {
      setState(() => _err = 'Failed to load categories: ${e.toString()}');
    } finally {
      setState(() => _loadingCats = false);
    }
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    var ct = x.mimeType ?? _guessMimeFromName(x.name);
    if (ct == 'application/octet-stream') ct = _guessMimeFromName(x.name);
    setState(() {
      _coverBytes = bytes;
      _coverName = x.name;
      _coverContentType = ct;
    });
  }

  String _guessMimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }

  Future<void> _pickGallery() async {
    final xs = await _picker.pickMultiImage(imageQuality: 85);
    if (xs.isEmpty) return;
    for (final x in xs) {
      final bytes = await x.readAsBytes();
      var ct = x.mimeType ?? _guessMimeFromName(x.name);
      if (ct == 'application/octet-stream') ct = _guessMimeFromName(x.name);
      setState(() {
        _gallery.add((bytes: bytes, name: x.name, contentType: ct));
      });
    }
  }

  void _clearGallery() => setState(() => _gallery.clear());

  Future<Map<String, dynamic>> _metadataPayload(
    String categoryId,
    String title,
    String description,
    double price,
  ) async {
    final meta = <String, dynamic>{
      'categoryId': categoryId,
      'title': title,
      'description': description,
      'priceType': 'FIXED',
      'priceAmount': price,
      'visibility': _pendingVisibility,
    };
    try {
      if (await Permission.locationWhenInUse.request().isGranted) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
        meta['latitude'] = pos.latitude;
        meta['longitude'] = pos.longitude;
      }
    } catch (_) {
      /* listing still created without coords */
    }
    return meta;
  }

  Future<void> _submit(String visibility) async {
    _pendingVisibility = visibility;
    final auth = context.read<AuthController>();
    final token = auth.token;
    if (token == null) return;

    final categoryId = _categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      setState(() => _err = 'Please select a category.');
      return;
    }
    if (_coverBytes == null || (_coverBytes?.isEmpty ?? true)) {
      setState(() => _err = 'Please add a cover image.');
      return;
    }
    if (_gallery.isEmpty) {
      setState(
        () => _err = 'Please add at least one gallery image besides the cover.',
      );
      return;
    }

    final title = _title.text.trim();
    final description = _description.text.trim();
    final price = double.tryParse(_priceAmount.text.trim());
    if (title.isEmpty || description.isEmpty) {
      setState(() => _err = 'Title and description are required.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _err = 'Price must be a valid number.');
      return;
    }

    setState(() {
      _submitting = true;
      _err = null;
    });
    try {
      final metadata = await _metadataPayload(
        categoryId,
        title,
        description,
        price,
      );
      final res = await apiMultipartServiceListingComplete(
        token,
        metadata: metadata,
        coverBytes: _coverBytes!,
        coverFilename: _coverName ?? 'cover.jpg',
        coverContentType: _coverContentType,
        gallery: _gallery
            .take(24)
            .map(
              (g) => (
                bytes: g.bytes,
                filename: g.name,
                contentType: g.contentType,
              ),
            )
            .toList(),
      );

      final listing = (res['listing'] as Map?)?.cast<String, dynamic>();
      final id = listing?['id']?.toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _pendingVisibility == 'DRAFT'
                ? 'Draft saved.'
                : 'Service listing published.',
          ),
        ),
      );
      if (id != null && id.isNotEmpty) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _err = 'Create failed: ${e.toString()}');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Widget _memoryThumb(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(bytes, height: 96, width: 96, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final body = Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageBackground),
          child: SizedBox.expand(),
        ),
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!canPop) ...[
              Text(
                'Create service',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Same photo flow as creating a product: cover + gallery.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'We save your GPS with the listing when permitted, so clients can find services near them.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_err != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(
                  _err!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            if (_err != null) const SizedBox(height: 12),
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
                child: _coverBytes == null
                    ? InkWell(
                        onTap: _submitting ? null : _pickCover,
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
                          Image.memory(_coverBytes!, fit: BoxFit.cover),
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
                                  onPressed: _submitting ? null : _pickCover,
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
                                  onPressed: _submitting
                                      ? null
                                      : () => setState(() {
                                          _coverBytes = null;
                                          _coverName = null;
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
                if (_gallery.isNotEmpty)
                  TextButton(
                    onPressed: _submitting ? null : _clearGallery,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
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
                      onTap: _submitting ? null : _pickGallery,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
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
                  ..._gallery.asMap().entries.map((e) {
                    final i = e.key;
                    final g = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          _memoryThumb(g.bytes),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _submitting
                                    ? null
                                    : () =>
                                          setState(() => _gallery.removeAt(i)),
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
            if (_gallery.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Add at least one photo besides the cover.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value:
                          _categoryId != null &&
                              _cats.any((c) => c.id == _categoryId)
                          ? _categoryId
                          : null,
                      items: _cats
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _categoryId = v),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    if (_loadingCats)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _priceAmount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (GMD)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _submit('DRAFT'),
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
                    onPressed: _submitting ? null : () => _submit('PUBLISHED'),
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
      ],
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create service')),
        body: body,
      );
    }
    return body;
  }
}
