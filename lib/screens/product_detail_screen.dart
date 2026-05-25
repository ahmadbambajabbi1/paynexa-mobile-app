import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/products_api.dart';
import '../auth/auth_controller.dart';
import '../models/product_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'edit_product_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductRow? _row;
  String? _err;
  bool _loading = true;
  bool _deleting = false;
  bool _bannerBusy = false;
  bool _galleryBusy = false;
  final Set<String> _removingKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final p = await fetchProduct(token, widget.productId);
      if (mounted) setState(() => _row = p);
    } catch (e) {
      if (mounted) setState(() => _err = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
    if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.jfif')) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  Future<void> _replaceBanner() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null || !mounted) return;
    setState(() => _bannerBusy = true);
    try {
      final bytes = await f.readAsBytes();
      final ct = await _guessMime(f);
      final updated = await replaceProductBanner(
        token,
        widget.productId,
        bannerBytes: bytes,
        bannerFilename: f.name,
        bannerContentType: ct,
      );
      if (mounted) setState(() => _row = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _bannerBusy = false);
    }
  }

  Future<void> _appendGallery() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty || !mounted) return;
    setState(() => _galleryBusy = true);
    try {
      final parts = <({List<int> bytes, String filename, String contentType})>[];
      for (final f in files) {
        parts.add((
          bytes: await f.readAsBytes(),
          filename: f.name,
          contentType: await _guessMime(f),
        ));
      }
      final updated = await appendProductGallery(token, widget.productId, parts);
      if (mounted) setState(() => _row = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _galleryBusy = false);
    }
  }

  Future<void> _removeGalleryKey(String key) async {
    final row = _row;
    if (row == null) return;
    if (row.otherImageKeys.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one gallery image must stay on the listing.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo'),
        content: const Text('This deletes the file from storage. You can add new photos anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _removingKeys.add(key));
    try {
      final updated = await removeProductGalleryKeys(token, widget.productId, [key]);
      if (mounted) setState(() => _row = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _removingKeys.remove(key));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: const Text(
          'This removes the listing and deletes all associated images from storage. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _deleting = true);
    try {
      await deleteProduct(token, widget.productId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _edit() async {
    final row = _row;
    if (row == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProductScreen(initial: row)),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          if (_row != null && !_loading)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
          if (_row != null && !_loading)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_err!)))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = _row!;
    final bannerUrl = p.productImages.isNotEmpty ? p.productImages.first : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            p.productType.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.gambianBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(productDisplayName(p), style: displayHeading(context).copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            'Updated ${p.updatedAt}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Text('Cover', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: bannerUrl != null
                  ? Image.network(bannerUrl, fit: BoxFit.cover)
                  : ColoredBox(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade500),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _bannerBusy ? null : _replaceBanner,
            icon: _bannerBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_back_outlined, size: 20),
            label: Text(_bannerBusy ? 'Uploading…' : 'Change cover'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
              const Spacer(),
              TextButton.icon(
                onPressed: _galleryBusy ? null : _appendGallery,
                icon: _galleryBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: Text(_galleryBusy ? 'Adding…' : 'Add photos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.otherImages.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('No gallery images.', style: TextStyle(color: Colors.grey.shade600)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(p.otherImages.length, (i) {
                final url = p.otherImages[i];
                final key = i < p.otherImageKeys.length ? p.otherImageKeys[i] : '';
                final busy = key.isNotEmpty && _removingKeys.contains(key);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(url, width: 108, height: 108, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: busy || key.isEmpty ? null : () => _removeGalleryKey(key),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          const SizedBox(height: 24),
          Text('Description', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          Text(p.description, style: const TextStyle(fontSize: 15, height: 1.4)),
          if (p.attributes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Details', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            ...p.attributes.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(e.key, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('${e.value}', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit),
            label: const Text('Edit details'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gambianBlue,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text(_deleting ? 'Deleting…' : 'Delete listing'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade800),
          ),
        ],
      ),
    );
  }
}
