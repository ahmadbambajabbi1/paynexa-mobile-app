import 'package:flutter/material.dart';

import '../models/product_models.dart';
import '../theme/app_colors.dart';
import 'product_image_lightbox.dart';

List<String> _collectProductImageUrls(ProductRow product) {
  final seen = <String>{};
  final out = <String>[];
  void add(String? u) {
    if (u == null || u.trim().isEmpty) return;
    final s = u.trim();
    if (seen.contains(s)) return;
    seen.add(s);
    out.add(s);
  }

  for (final u in product.productImages) {
    add(u);
  }
  for (final u in product.otherImages) {
    add(u);
  }
  for (final d in product.productType.fieldDefinitions) {
    final raw = product.attributes[d.name];
    if (raw is String &&
        (d.valueType == 'image' || d.valueType == 'url') &&
        (raw.startsWith('http://') || raw.startsWith('https://'))) {
      add(raw);
    }
  }
  return out;
}

void _openProductImage(BuildContext context, ProductRow product, String url) {
  final urls = _collectProductImageUrls(product);
  if (urls.isEmpty) return;
  final i = urls.indexOf(url.trim());
  showProductImageLightbox(context, urls: urls, initialIndex: i >= 0 ? i : 0);
}

/// Product banner, gallery, description, price, and dynamic type attributes (read-only).
class TransactionRoomProductSection extends StatelessWidget {
  const TransactionRoomProductSection({super.key, required this.product});

  final ProductRow product;

  @override
  Widget build(BuildContext context) {
    final gallery = product.otherImages;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryColorBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  productDisplayName(product),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  product.productType.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (product.productImages.isNotEmpty)
            Semantics(
              button: true,
              label: 'View product image larger',
              child: InkWell(
                onTap: () => _openProductImage(
                  context,
                  product,
                  product.productImages.first,
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    product.productImages.first,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 118,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        'D${product.price}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryColorBlack,
                        ),
                      ),
                    ),
                  ],
                ),
                if (gallery.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Gallery',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: gallery.length,
                    itemBuilder: (ctx, i) {
                      final url = gallery[i];
                      return Semantics(
                        button: true,
                        label: 'View gallery image larger',
                        child: Material(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                _openProductImage(context, product, url),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Image.network(url, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (product.productType.fieldDefinitions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...product.productType.fieldDefinitions.map((d) {
                    final raw = product.attributes[d.name];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade100),
                          color: Colors.blue.shade50.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.label ?? d.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _attrValue(context, product, d.valueType, raw),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attrValue(
    BuildContext context,
    ProductRow product,
    String valueType,
    dynamic raw,
  ) {
    if (raw == null) {
      return Text(
        '—',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      );
    }
    if (valueType == 'boolean') {
      return Text(
        raw == true ? 'Yes' : 'No',
        style: const TextStyle(fontSize: 14),
      );
    }
    if (raw is String) {
      if ((valueType == 'image' || valueType == 'url') &&
          (raw.startsWith('http://') || raw.startsWith('https://'))) {
        return Semantics(
          button: true,
          label: 'View detail image larger',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openProductImage(context, product, raw),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(raw, height: 96, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      }
      return SelectableText(raw, style: const TextStyle(fontSize: 14));
    }
    return SelectableText('$raw', style: const TextStyle(fontSize: 14));
  }
}
