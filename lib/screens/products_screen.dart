// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../api/api_error.dart';
// import '../api/products_api.dart';
// import '../auth/auth_controller.dart';
// import '../models/product_models.dart';
// import '../theme/app_colors.dart';
// import '../theme/app_theme.dart';
// import 'create_product_screen.dart';
// import 'product_detail_screen.dart';

// class ProductsScreen extends StatefulWidget {
//   const ProductsScreen({super.key});

//   @override
//   State<ProductsScreen> createState() => _ProductsScreenState();
// }

// class _ProductsScreenState extends State<ProductsScreen> {
//   static const _pageSize = 12;

//   final ScrollController _scroll = ScrollController();

//   List<ProductRow> _items = [];
//   int _nextPage = 1;
//   int _totalPages = 1;
//   int _total = 0;
//   String? _listErr;
//   bool _listLoading = true;
//   bool _loadingMore = false;

//   @override
//   void initState() {
//     super.initState();
//     _scroll.addListener(_onScroll);
//     WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(reset: true));
//   }

//   @override
//   void dispose() {
//     _scroll.removeListener(_onScroll);
//     _scroll.dispose();
//     super.dispose();
//   }

//   void _onScroll() {
//     if (_loadingMore || _listLoading) return;
//     if (_nextPage > _totalPages) return;
//     final pos = _scroll.position;
//     if (!pos.hasPixels) return;
//     if (pos.pixels >= pos.maxScrollExtent - 280) {
//       _loadMore();
//     }
//   }

//   /// Reloads from page 1 (pull-to-refresh or after create / delete).
//   Future<void> _refresh({bool reset = false}) async {
//     final token = context.read<AuthController>().token;
//     if (token == null) return;
//     if (reset) {
//       setState(() {
//         _listLoading = true;
//         _items = [];
//         _nextPage = 1;
//         _listErr = null;
//       });
//     } else {
//       setState(() => _listLoading = true);
//     }
//     try {
//       final res = await listMyProducts(token, 1, _pageSize);
//       if (!mounted) return;
//       setState(() {
//         _items = List<ProductRow>.from(res.items);
//         _totalPages = res.totalPages;
//         _total = res.total;
//         _nextPage = res.totalPages > 0 ? 2 : 1;
//         if (_nextPage > res.totalPages) {
//           _nextPage = res.totalPages + 1;
//         }
//         _listErr = null;
//       });
//     } catch (e) {
//       if (mounted) setState(() => _listErr = errorMessage(e));
//     } finally {
//       if (mounted) setState(() => _listLoading = false);
//     }
//   }

//   Future<void> _loadMore() async {
//     if (_loadingMore || _nextPage > _totalPages) return;
//     final token = context.read<AuthController>().token;
//     if (token == null) return;
//     setState(() => _loadingMore = true);
//     try {
//       final res = await listMyProducts(token, _nextPage, _pageSize);
//       if (!mounted) return;
//       setState(() {
//         _items = [..._items, ...res.items];
//         _totalPages = res.totalPages;
//         _total = res.total;
//         _nextPage = _nextPage + 1;
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
//       }
//     } finally {
//       if (mounted) setState(() => _loadingMore = false);
//     }
//   }

//   Future<void> _openCreate() async {
//     final created = await Navigator.of(context).push<bool>(
//       MaterialPageRoute(builder: (_) => const CreateProductScreen()),
//     );
//     if (created == true && mounted) await _refresh(reset: true);
//   }

//   String _excerpt(String text, int max) {
//     final t = text.trim();
//     if (t.length <= max) return t;
//     return '${t.substring(0, max)}…';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Row(
//           children: [
//             Expanded(child: Text('Products', style: displayHeading(context))),
//             FilledButton.icon(
//               onPressed: _openCreate,
//               style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColorBlack),
//               icon: const Icon(Icons.add, size: 20),
//               label: const Text('Create product'),
//             ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           'Your listings — scroll down to load more.',
//           style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//         ),
//         const SizedBox(height: 16),
//         Expanded(child: _buildListBody()),
//       ],
//     );
//   }

//   Widget _buildListBody() {
//     if (_listLoading && _items.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (_listErr != null && _items.isEmpty) {
//       return Center(child: Text(_listErr!, style: TextStyle(color: Colors.red.shade700)));
//     }
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         if (_total > 0)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 12),
//             child: Text(
//               '${_items.length} of $_total loaded',
//               style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
//             ),
//           ),
//         Expanded(
//           child: RefreshIndicator(
//             onRefresh: () => _refresh(reset: true),
//             child: _items.isEmpty
//                 ? ListView(
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     children: [
//                       SizedBox(
//                         height: MediaQuery.sizeOf(context).height * 0.35,
//                         child: Center(
//                           child: Text(
//                             'No products yet.',
//                             style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
//                           ),
//                         ),
//                       ),
//                     ],
//                   )
//                 : ListView.builder(
//                     controller: _scroll,
//                     physics: const AlwaysScrollableScrollPhysics(),
//                     padding: const EdgeInsets.only(bottom: 24),
//                     itemCount: _items.length + (_loadingMore ? 1 : 0),
//                     itemBuilder: (context, i) {
//                       if (i >= _items.length) {
//                         return const Padding(
//                           padding: EdgeInsets.symmetric(vertical: 20),
//                           child: Center(child: CircularProgressIndicator()),
//                         );
//                       }
//                       final p = _items[i];
//                       final img = p.productImages.isNotEmpty ? p.productImages.first : null;
//                       return Padding(
//                         padding: const EdgeInsets.only(bottom: 14),
//                         child: Material(
//                           color: Colors.transparent,
//                           child: InkWell(
//                             borderRadius: BorderRadius.circular(18),
//                             onTap: () async {
//                               final changed = await Navigator.of(context).push<bool>(
//                                 MaterialPageRoute(
//                                   builder: (_) => ProductDetailScreen(productId: p.id),
//                                 ),
//                               );
//                               if (changed == true && mounted) await _refresh(reset: true);
//                             },
//                             child: Ink(
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(18),
//                                 border: Border.all(color: Colors.grey.shade200),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withValues(alpha: 0.05),
//                                     blurRadius: 12,
//                                     offset: const Offset(0, 4),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                                 children: [
//                                   ClipRRect(
//                                     borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
//                                     child: AspectRatio(
//                                       aspectRatio: 16 / 9,
//                                       child: img != null
//                                           ? Image.network(img, fit: BoxFit.cover)
//                                           : ColoredBox(
//                                               color: Colors.grey.shade200,
//                                               child: Icon(Icons.image, color: Colors.grey.shade400, size: 48),
//                                             ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           p.productType.name,
//                                           style: const TextStyle(
//                                             fontSize: 12,
//                                             fontWeight: FontWeight.w700,
//                                             letterSpacing: 0.4,
//                                             color: AppColors.primaryColorBlack,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Text(
//                                           productDisplayName(p),
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                           style: const TextStyle(
//                                             fontSize: 17,
//                                             fontWeight: FontWeight.w600,
//                                             height: 1.25,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 6),
//                                         Text(
//                                           _excerpt(p.description, 180),
//                                           maxLines: 3,
//                                           overflow: TextOverflow.ellipsis,
//                                           style: TextStyle(fontSize: 14, height: 1.35, color: Colors.grey.shade700),
//                                         ),
//                                         const SizedBox(height: 10),
//                                         Text(
//                                           'Updated ${p.updatedAt}',
//                                           style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/products_api.dart';
import '../auth/auth_controller.dart';
import '../models/product_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'create_product_screen.dart';
import 'product_detail_screen.dart';

const _blue = AppColors.primaryColorBlack;
const _blueTint = Color(0xFFE8EBFA);
const _blueBorder = Color(0xFFB5BEF0);

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const _pageSize = 12;

  final ScrollController _scroll = ScrollController();

  List<ProductRow> _items = [];
  int _nextPage = 1;
  int _totalPages = 1;
  int _total = 0;
  String? _listErr;
  bool _listLoading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(reset: true));
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _listLoading) return;
    if (_nextPage > _totalPages) return;
    final pos = _scroll.position;
    if (!pos.hasPixels) return;
    if (pos.pixels >= pos.maxScrollExtent - 280) _loadMore();
  }

  Future<void> _refresh({bool reset = false}) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    if (reset) {
      setState(() {
        _listLoading = true;
        _items = [];
        _nextPage = 1;
        _listErr = null;
      });
    } else {
      setState(() => _listLoading = true);
    }
    try {
      final res = await listMyProducts(token, 1, _pageSize);
      if (!mounted) return;
      setState(() {
        _items = List<ProductRow>.from(res.items);
        _totalPages = res.totalPages;
        _total = res.total;
        _nextPage = res.totalPages > 0 ? 2 : 1;
        if (_nextPage > res.totalPages) _nextPage = res.totalPages + 1;
        _listErr = null;
      });
    } catch (e) {
      if (mounted) setState(() => _listErr = errorMessage(e));
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextPage > _totalPages) return;
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _loadingMore = true);
    try {
      final res = await listMyProducts(token, _nextPage, _pageSize);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...res.items];
        _totalPages = res.totalPages;
        _total = res.total;
        _nextPage = _nextPage + 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateProductScreen()),
    );
    if (created == true && mounted) await _refresh(reset: true);
  }

  String _excerpt(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: const Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              _CreateButton(onTap: _openCreate),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _total > 0
                ? '${_items.length} of $_total loaded - scroll for more'
                : 'Your product catalog',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _ProductSummary(items: _items, total: _total),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_listLoading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_listErr != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _blueTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_outlined,
                  size: 28,
                  color: _blue.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _listErr!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(reset: true),
      color: _blue,
      backgroundColor: Colors.white,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [_EmptyProductsState(onTap: _openCreate)],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(color: _blue),
                    ),
                  );
                }
                final p = _items[i];
                final img = p.productImages.isNotEmpty
                    ? p.productImages.first
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProductCard(
                    name: productDisplayName(p),
                    typeName: p.productType.name,
                    description: _excerpt(p.description, 160),
                    updatedAt: p.updatedAt,
                    visibility: p.visibility,
                    imageUrl: img,
                    onPublish: p.visibility == 'DRAFT'
                        ? () async {
                            final token = context.read<AuthController>().token;
                            if (token == null) return;
                            try {
                              await publishProduct(token, p.id);
                              if (mounted) await _refresh(reset: true);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage(e))),
                                );
                              }
                            }
                          }
                        : null,
                    onTap: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(productId: p.id),
                        ),
                      );
                      if (changed == true && mounted) {
                        await _refresh(reset: true);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({required this.items, required this.total});

  final List<ProductRow> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    final drafts = items.where((p) => p.visibility == 'DRAFT').length;
    final published = items.length - drafts;
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Owned',
            value: '${total > 0 ? total : items.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(label: 'Published', value: '$published'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(label: 'Drafts', value: '$drafts'),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blueBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _blue,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Create button ────────────────────────────────────────────────────────────

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add, size: 16, color: Colors.white),
            SizedBox(width: 5),
            Text(
              'Create',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final String name;
  final String typeName;
  final String description;
  final String updatedAt;
  final String visibility;
  final String? imageUrl;
  final Future<void> Function()? onPublish;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.typeName,
    required this.description,
    required this.updatedAt,
    required this.visibility,
    required this.imageUrl,
    required this.onPublish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _blueBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: _blue.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _PlaceholderImg(),
                        )
                      : _PlaceholderImg(),
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            typeName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: _blue,
                            ),
                          ),
                        ),
                        if (visibility == 'DRAFT')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Draft',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Updated $updatedAt',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const Spacer(),
                        if (onPublish != null)
                          TextButton(
                            onPressed: () => onPublish!(),
                            style: TextButton.styleFrom(
                              foregroundColor: _blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: const Text(
                              'Publish',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _blueTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Manage',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _blue,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10,
                                  color: _blue,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderImg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _blueTint,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: _blue.withOpacity(0.25),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyProductsState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyProductsState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blueBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _blueTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 28,
              color: _blue.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first product to start selling on the marketplace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onTap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add your first product',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
