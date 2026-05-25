// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';

// import '../api/service_marketplace_api.dart' as sm;
// import '../auth/auth_controller.dart';
// import '../theme/app_colors.dart';
// import '../theme/app_theme.dart';
// import 'marketplace_create_service_screen.dart';
// import 'service_detail_screen.dart';

// String? _coverFromListing(Map<String, dynamic> raw) {
//   final c = raw['coverImage'];
//   if (c is String && c.startsWith('http')) return c;
//   return null;
// }

// class MarketplaceServicesScreen extends StatefulWidget {
//   const MarketplaceServicesScreen({super.key});

//   @override
//   State<MarketplaceServicesScreen> createState() => _MarketplaceServicesScreenState();
// }

// class _MarketplaceServicesScreenState extends State<MarketplaceServicesScreen> {
//   bool _loading = false;
//   String? _err;
//   List<Map<String, dynamic>> _items = const [];
//   Timer? _locTimer;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
//     _locTimer = Timer.periodic(const Duration(minutes: 3), (_) {
//       unawaited(_throttledRenderingPing());
//     });
//   }

//   @override
//   void dispose() {
//     _locTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _throttledRenderingPing() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null) return;
//     if (!await Permission.locationWhenInUse.isGranted) return;
//     try {
//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.medium,
//         timeLimit: const Duration(seconds: 15),
//       );
//       await sm.maybePingRenderingLocation(
//         token: token,
//         latitude: pos.latitude,
//         longitude: pos.longitude,
//       );
//     } catch (_) {}
//   }

//   Future<void> _refresh() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null) return;
//     setState(() {
//       _loading = true;
//       _err = null;
//     });
//     try {
//       final rows = await sm.listMyServiceListings(token: token);
//       if (!mounted) return;
//       setState(() {
//         _items = rows;
//         _err = null;
//       });
//       unawaited(_throttledRenderingPing());
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _err = e.toString());
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   Future<void> _openCreate() async {
//     final created = await Navigator.of(context).push<bool>(
//       MaterialPageRoute(builder: (_) => const MarketplaceCreateServiceScreen()),
//     );
//     if (created == true && mounted) await _refresh();
//   }

//   String _excerpt(String text, int max) {
//     final t = text.trim();
//     if (t.length <= max) return t;
//     return '${t.substring(0, max)}…';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         const DecoratedBox(
//           decoration: BoxDecoration(gradient: AppColors.pageBackground),
//           child: SizedBox.expand(),
//         ),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//               child: Row(
//                 children: [
//                   Expanded(child: Text('My services', style: displayHeading(context))),
//                   FilledButton.icon(
//                     onPressed: _openCreate,
//                     style: FilledButton.styleFrom(backgroundColor: AppColors.gambianBlue),
//                     icon: const Icon(Icons.add, size: 20),
//                     label: const Text('Create service'),
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//               child: Text(
//                 'Your listings — same pattern as Products.',
//                 style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
//               ),
//             ),
//             Expanded(child: _buildList()),
//           ],
//         ),
//         if (_loading && _items.isNotEmpty)
//           const Positioned(
//             left: 0,
//             right: 0,
//             top: 0,
//             child: LinearProgressIndicator(minHeight: 2),
//           ),
//       ],
//     );
//   }

//   Widget _buildList() {
//     if (_items.isEmpty && _loading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (_err != null && _items.isEmpty) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Text(_err!, style: TextStyle(color: Colors.red.shade700)),
//         ),
//       );
//     }
//     if (_items.isEmpty && !_loading) {
//       return ListView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.all(24),
//         children: [
//           SizedBox(
//             height: MediaQuery.sizeOf(context).height * 0.25,
//             child: Center(
//               child: Text(
//                 'No service listings yet.',
//                 style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Center(
//             child: FilledButton.icon(
//               onPressed: _openCreate,
//               icon: const Icon(Icons.add),
//               label: const Text('Create your first service'),
//             ),
//           ),
//         ],
//       );
//     }
//     return RefreshIndicator(
//       onRefresh: _refresh,
//       child: ListView.builder(
//         physics: const AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
//         itemCount: _items.length,
//         itemBuilder: (context, i) {
//           final raw = _items[i];
//           final id = raw['id'] as String;
//           final title = (raw['title'] as String?) ?? '';
//           final desc = (raw['description'] as String?) ?? '';
//           final cat = (raw['category'] as Map<String, dynamic>?)?['name'] as String? ?? 'Service';
//           final pt = (raw['priceType'] as String?) ?? 'FIXED';
//           final priceLabel = pt == 'FIXED'
//               ? 'D${raw['priceAmount'] ?? ''}'
//               : 'D${raw['priceMin'] ?? ''}–D${raw['priceMax'] ?? ''}';
//           final img = _coverFromListing(raw);
//           return Padding(
//             padding: const EdgeInsets.only(bottom: 14),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(18),
//                 onTap: () async {
//                   await Navigator.of(context).push(
//                     MaterialPageRoute(
//                       builder: (_) => ServiceDetailScreen(listingId: id),
//                     ),
//                   );
//                   if (mounted) await _refresh();
//                 },
//                 child: Ink(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(18),
//                     border: Border.all(color: Colors.grey.shade200),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withValues(alpha: 0.05),
//                         blurRadius: 12,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       ClipRRect(
//                         borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
//                         child: AspectRatio(
//                           aspectRatio: 16 / 9,
//                           child: img != null
//                               ? Image.network(img, fit: BoxFit.cover)
//                               : ColoredBox(
//                                   color: Colors.grey.shade200,
//                                   child: Icon(Icons.image, color: Colors.grey.shade400, size: 48),
//                                 ),
//                         ),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               cat,
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w700,
//                                 letterSpacing: 0.4,
//                                 color: AppColors.gambianBlue,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               title,
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               _excerpt(desc, 180),
//                               maxLines: 3,
//                               overflow: TextOverflow.ellipsis,
//                               style: TextStyle(fontSize: 14, height: 1.35, color: Colors.grey.shade700),
//                             ),
//                             const SizedBox(height: 10),
//                             Text(priceLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../api/service_marketplace_api.dart' as sm;
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'marketplace_create_service_screen.dart';
import 'service_detail_screen.dart';

const _blue = AppColors.gambianBlue;
const _blueTint = Color(0xFFE8EBFA);
const _blueBorder = Color(0xFFB5BEF0);

String? _coverFromListing(Map<String, dynamic> raw) {
  final c = raw['coverImage'];
  if (c is String && c.startsWith('http')) return c;
  return null;
}

class MarketplaceServicesScreen extends StatefulWidget {
  const MarketplaceServicesScreen({super.key});

  @override
  State<MarketplaceServicesScreen> createState() =>
      _MarketplaceServicesScreenState();
}

class _MarketplaceServicesScreenState extends State<MarketplaceServicesScreen> {
  bool _loading = false;
  String? _err;
  List<Map<String, dynamic>> _items = const [];
  Timer? _locTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _locTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      unawaited(_throttledRenderingPing());
    });
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    super.dispose();
  }

  Future<void> _throttledRenderingPing() async {
    final token = context.read<AuthController>().token;
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

  Future<void> _refresh() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final rows = await sm.listMyServiceListings(token: token);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _err = null;
      });
      unawaited(_throttledRenderingPing());
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MarketplaceCreateServiceScreen()),
    );
    if (created == true && mounted) await _refresh();
  }

  String _excerpt(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageBackground),
          child: SizedBox.expand(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Services',
                      style: const TextStyle(
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
                'Your active service listings',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ServiceSummary(items: _items),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
        if (_loading && _items.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: _blue,
              backgroundColor: _blueTint,
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_err != null && _items.isEmpty) {
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
                _err!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty && !_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [_EmptyServicesState(onTap: _openCreate)],
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: _blue,
      backgroundColor: Colors.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final raw = _items[i];
          final id = raw['id'] as String;
          final title = (raw['title'] as String?) ?? '';
          final desc = (raw['description'] as String?) ?? '';
          final cat =
              (raw['category'] as Map<String, dynamic>?)?['name'] as String? ??
              'Service';
          final pt = (raw['priceType'] as String?) ?? 'FIXED';
          final priceLabel = pt == 'FIXED'
              ? 'D${raw['priceAmount'] ?? ''}'
              : 'D${raw['priceMin'] ?? ''}–D${raw['priceMax'] ?? ''}';
          final img = _coverFromListing(raw);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ServiceCard(
              id: id,
              title: title,
              description: _excerpt(desc, 160),
              category: cat,
              priceLabel: priceLabel,
              visibility: (raw['visibility'] as String?) ?? 'PUBLISHED',
              imageUrl: img,
              onPublish:
                  ((raw['visibility'] as String?) ?? 'PUBLISHED') == 'DRAFT'
                  ? () async {
                      final token = context.read<AuthController>().token;
                      if (token == null) return;
                      try {
                        await sm.publishServiceListing(
                          token: token,
                          listingId: id,
                        );
                        if (mounted) await _refresh();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    }
                  : null,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailScreen(listingId: id),
                  ),
                );
                if (mounted) await _refresh();
              },
            ),
          );
        },
      ),
    );
  }
}

class _ServiceSummary extends StatelessWidget {
  const _ServiceSummary({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final drafts = items
        .where((s) => '${s['visibility'] ?? 'PUBLISHED'}' == 'DRAFT')
        .length;
    final published = items.length - drafts;
    return Row(
      children: [
        Expanded(
          child: _MiniStat(label: 'Owned', value: '${items.length}'),
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

// ─── Service card ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priceLabel;
  final String visibility;
  final String? imageUrl;
  final Future<void> Function()? onPublish;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priceLabel,
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
                            category.toUpperCase(),
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
                      title,
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          priceLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: _blue,
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
          Icons.image_outlined,
          size: 40,
          color: _blue.withOpacity(0.25),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyServicesState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyServicesState({required this.onTap});

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
              Icons.work_outline,
              size: 28,
              color: _blue.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No listings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first service listing to start receiving bookings.',
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
                'Create your first service',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
