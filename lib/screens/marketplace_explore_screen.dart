// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:provider/provider.dart';

// import '../api/service_marketplace_api.dart' as sm;
// import '../auth/auth_controller.dart';
// import '../theme/app_colors.dart';
// import 'service_detail_screen.dart';

// class MarketplaceExploreScreen extends StatefulWidget {
//   const MarketplaceExploreScreen({super.key});

//   @override
//   State<MarketplaceExploreScreen> createState() => _MarketplaceExploreScreenState();
// }

// class _MarketplaceExploreScreenState extends State<MarketplaceExploreScreen> {
//   bool _loading = false;
//   String? _err;
//   double? _lat;
//   double? _lng;
//   double? _accuracy;
//   bool _onlineOnly = false;
//   String? _categoryId;
//   List<sm.ServiceCategory> _categories = const [];
//   List<sm.ServiceListingRow> _items = const [];
//   Timer? _geoRefreshTimer;

//   @override
//   void initState() {
//     super.initState();
//     _bootstrap();
//     _geoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
//       if (!mounted) return;
//       unawaited(_refreshLocationQuiet());
//     });
//   }

//   @override
//   void dispose() {
//     _geoRefreshTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _bootstrap() async {
//     await _loadCategories();
//     await _ensureLocationDecision();
//     if (mounted) await _search();
//   }

//   Future<void> _ensureLocationDecision() async {
//     // Match web behavior: allow browsing without location, but ask once up-front.
//     final has = await _tryGetLocation(interactivePrompt: true);
//     if (!mounted) return;
//     if (!has) {
//       setState(() {
//         _lat = null;
//         _lng = null;
//         _accuracy = null;
//       });
//     }
//   }

//   Future<void> _loadCategories() async {
//     try {
//       final cats = await sm.listServiceCategories();
//       if (!mounted) return;
//       setState(() {
//         _categories = cats;
//         _categoryId ??= null;
//       });
//     } catch (_) {
//       /* browse works without categories */
//     }
//   }

//   Future<bool> _tryGetLocation({required bool interactivePrompt}) async {
//     setState(() {
//       _err = null;
//       _loading = true;
//     });
//     try {
//       if (interactivePrompt && mounted) {
//         final allow = await showDialog<bool>(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: const Text('Use your location?'),
//             content: const Text(
//               'We use your location to sort providers by distance. You can continue without it.',
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, false),
//                 child: const Text('Not now'),
//               ),
//               FilledButton(
//                 onPressed: () => Navigator.pop(context, true),
//                 child: const Text('Allow location'),
//               ),
//             ],
//           ),
//         );
//         if (allow != true) {
//           setState(() {
//             _err = null;
//             _lat = null;
//             _lng = null;
//             _accuracy = null;
//           });
//           return false;
//         }
//       }

//       final enabled = await Geolocator.isLocationServiceEnabled();
//       if (!enabled) {
//         setState(() {
//           _err = 'Location services are off. Enable GPS to sort by distance.';
//         });
//         return false;
//       }

//       var perm = await Geolocator.checkPermission();
//       if (perm == LocationPermission.denied) {
//         perm = await Geolocator.requestPermission();
//       }
//       if (perm == LocationPermission.deniedForever) {
//         setState(() {
//           _err =
//               'Location permission is blocked. Enable it in Settings to sort by distance.';
//         });
//         await Geolocator.openAppSettings();
//         return false;
//       }
//       if (perm == LocationPermission.denied) {
//         setState(() {
//           _err = 'Location permission denied. Showing best-rated services.';
//         });
//         return false;
//       }

//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.bestForNavigation,
//         timeLimit: const Duration(seconds: 12),
//       );
//       setState(() {
//         _lat = pos.latitude;
//         _lng = pos.longitude;
//         _accuracy = pos.accuracy;
//       });
//       await _maybePingProviderRendering(pos.latitude, pos.longitude);
//       return true;
//     } catch (e) {
//       setState(() {
//         _err =
//             'Could not read GPS (${e.toString()}). Searching without distance.';
//         _lat = null;
//         _lng = null;
//       });
//       return false;
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _refreshLocationQuiet() async {
//     final perm = await Geolocator.checkPermission();
//     if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
//       return;
//     }
//     try {
//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.medium,
//         timeLimit: const Duration(seconds: 15),
//       );
//       if (!mounted) return;
//       setState(() {
//         _lat = pos.latitude;
//         _lng = pos.longitude;
//         _accuracy = pos.accuracy;
//       });
//       await _maybePingProviderRendering(pos.latitude, pos.longitude);
//       if (mounted) await _search();
//     } catch (_) {
//       /* ignore periodic failures */
//     }
//   }

//   Future<void> _maybePingProviderRendering(double lat, double lng) async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null) return;
//     await sm.maybePingRenderingLocation(token: token, latitude: lat, longitude: lng);
//   }

//   Future<void> _search() async {
//     setState(() {
//       _err = null;
//       _loading = true;
//     });
//     try {
//       final results = await sm.searchServiceListings(
//         latitude: _lat,
//         longitude: _lng,
//         categoryId: _categoryId,
//         onlineOnly: _onlineOnly,
//       );
//       setState(() => _items = results);
//     } catch (e) {
//       setState(() => _err = 'Search failed: ${e.toString()}');
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _openDetail(sm.ServiceListingRow row) async {
//     await Navigator.of(context).push<bool>(
//       MaterialPageRoute(
//         builder: (_) => ServiceDetailScreen(listingId: row.id),
//       ),
//     );
//     if (mounted) await _search();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final accuracy = _accuracy != null ? ' ±${_accuracy!.round()}m' : '';

//     return Stack(
//       children: [
//         const DecoratedBox(
//           decoration: BoxDecoration(gradient: AppColors.pageBackground),
//           child: SizedBox.expand(),
//         ),
//         ListView(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//           children: [
//             Text(
//               'Explore',
//               style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               _lat != null && _lng != null
//                   ? 'Nearby services are ranked using your location$accuracy'
//                   : 'Location unavailable: showing best-rated services',
//               style: TextStyle(color: Colors.grey.shade600),
//             ),
//             if (_err != null) ...[
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.shade50,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.orange.shade100),
//                 ),
//                 child: Text(_err!, style: TextStyle(color: Colors.orange.shade900)),
//               ),
//             ],
//             const SizedBox(height: 12),
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Row(
//                       children: [
//                         Icon(Icons.tune, size: 18, color: AppColors.gambianBlue),
//                         SizedBox(width: 8),
//                         Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     DropdownButtonFormField<String?>(
//                       value: _categoryId,
//                       decoration: const InputDecoration(
//                         labelText: 'Category',
//                         prefixIcon: Icon(Icons.category_outlined),
//                       ),
//                       items: [
//                         const DropdownMenuItem<String?>(value: null, child: Text('All')),
//                         ..._categories.map(
//                           (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
//                         ),
//                       ],
//                       onChanged: (v) {
//                         setState(() => _categoryId = v);
//                         unawaited(_search());
//                       },
//                     ),
//                     const SizedBox(height: 10),
//                     SwitchListTile.adaptive(
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         side: BorderSide(color: Colors.grey.shade200),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//                       value: _onlineOnly,
//                       onChanged: (v) {
//                         setState(() => _onlineOnly = v);
//                         unawaited(_search());
//                       },
//                       title: const Text('Online only'),
//                       subtitle: const Text('Show only providers marked online'),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),
//             if (_items.isEmpty && !_loading)
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 30),
//                 child: Text(
//                   'No services found yet.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.grey.shade600),
//                 ),
//               ),
//             for (final row in _items) _ListingCard(row: row, onOpen: () => _openDetail(row)),
//           ],
//         ),
//         if (_loading)
//           const Positioned(
//             left: 0,
//             right: 0,
//             top: 0,
//             child: LinearProgressIndicator(minHeight: 2),
//           ),
//       ],
//     );
//   }
// }

// class _ListingCard extends StatelessWidget {
//   const _ListingCard({required this.row, required this.onOpen});

//   final sm.ServiceListingRow row;
//   final VoidCallback onOpen;

//   Color _statusColor(String s) {
//     if (s == 'ONLINE') return Colors.green.shade600;
//     if (s == 'AWAY') return Colors.orange.shade700;
//     return Colors.grey.shade600;
//   }

//   String? _responseLine(int sec) {
//     if (sec <= 0) return null;
//     if (sec < 45) return '~1m';
//     if (sec < 3600) {
//       final m = (sec / 60).round().clamp(1, 999);
//       return '~${m}m';
//     }
//     final h = (sec / 3600).round().clamp(1, 999);
//     return h == 1 ? '~1h' : '~${h}h';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final response = _responseLine(row.avgResponseTimeSec);
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: onOpen,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             AspectRatio(
//               aspectRatio: 16 / 10,
//               child: Stack(
//                 fit: StackFit.expand,
//                 children: [
//                   row.coverImageUrl != null
//                       ? Image.network(
//                           row.coverImageUrl!,
//                           fit: BoxFit.cover,
//                           errorBuilder: (_, __, ___) => ColoredBox(
//                             color: Colors.grey.shade300,
//                             child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade600),
//                           ),
//                         )
//                       : ColoredBox(
//                           color: Colors.grey.shade300,
//                           child: Icon(Icons.image_outlined, color: Colors.grey.shade600, size: 40),
//                         ),
//                   Positioned(
//                     right: 10,
//                     top: 10,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                       decoration: BoxDecoration(
//                         color: _statusColor(row.status).withValues(alpha: 0.18),
//                         borderRadius: BorderRadius.circular(999),
//                         border: Border.all(color: _statusColor(row.status).withValues(alpha: 0.22)),
//                       ),
//                       child: Text(
//                         row.status,
//                         style: TextStyle(
//                           fontWeight: FontWeight.w800,
//                           color: _statusColor(row.status),
//                           fontSize: 11,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     row.categoryName.toUpperCase(),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 11,
//                       fontWeight: FontWeight.w800,
//                       letterSpacing: 0.6,
//                       color: AppColors.gambianBlue,
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Text(row.title, style: const TextStyle(fontWeight: FontWeight.w800)),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     row.providerName,
//                     style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                   ),
//                   if (row.providerLocationLine != null) ...[
//                     const SizedBox(height: 6),
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
//                         const SizedBox(width: 6),
//                         Expanded(
//                           child: Text(
//                             row.providerLocationLine!,
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.25),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                   const SizedBox(height: 8),
//                   Text(
//                     row.description,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(color: Colors.grey.shade700),
//                   ),
//                   const SizedBox(height: 10),
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: [
//                       _Chip(
//                         icon: Icons.star_rounded,
//                         iconColor: Colors.amber.shade700,
//                         text: '${row.ratingAvg.toStringAsFixed(1)} (${row.ratingCount})',
//                       ),
//                       if (row.distanceKm != null)
//                         _Chip(
//                           icon: Icons.location_searching,
//                           iconColor: AppColors.gambianBlue,
//                           text: '${row.distanceKm!.toStringAsFixed(1)} km',
//                           bg: Colors.blue.shade50,
//                           fg: AppColors.gambianBlue,
//                         ),
//                       if (response != null)
//                         _Chip(
//                           icon: Icons.bolt,
//                           iconColor: Colors.orange.shade700,
//                           text: response,
//                           bg: Colors.orange.shade50,
//                           fg: Colors.orange.shade900,
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     children: [
//                       Text(row.priceLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
//                       const Spacer(),
//                       Text(
//                         'View',
//                         style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gambianBlue),
//                       ),
//                       const SizedBox(width: 6),
//                       Icon(Icons.chevron_right, size: 18, color: AppColors.gambianBlue),
//                     ],
//                   )
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _Chip extends StatelessWidget {
//   const _Chip({
//     required this.icon,
//     required this.text,
//     required this.iconColor,
//     this.bg,
//     this.fg,
//   });

//   final IconData icon;
//   final String text;
//   final Color iconColor;
//   final Color? bg;
//   final Color? fg;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: bg ?? Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 16, color: iconColor),
//           const SizedBox(width: 6),
//           Text(
//             text,
//             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg ?? Colors.grey.shade800),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/service_marketplace_api.dart' as sm;
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import 'notifications_screen.dart';
import 'service_detail_screen.dart';

const _kLocationDecisionKey = 'marketplace_location_decision_made';

// ─── Palette helpers ────────────────────────────────────────────────────────
const _blue = AppColors.gambianBlue;          // #0C1C8C  – primary
const _blueTint = Color(0xFFE8EBFA);           // light blue fill
const _blueBorder = Color(0xFFB5BEF0);         // subtle blue border

class MarketplaceExploreScreen extends StatefulWidget {
  const MarketplaceExploreScreen({super.key});

  @override
  State<MarketplaceExploreScreen> createState() =>
      _MarketplaceExploreScreenState();
}

class _MarketplaceExploreScreenState
    extends State<MarketplaceExploreScreen> {
  bool _loading = false;
  String? _err;
  double? _lat;
  double? _lng;
  bool _onlineOnly = false;
  String? _categoryId;
  List<sm.ServiceCategory> _categories = const [];
  List<sm.ServiceListingRow> _items = const [];
  Timer? _geoRefreshTimer;
  bool _locationDecisionMade = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLocationDecision();
    _bootstrap();
    _geoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (!mounted) return;
      unawaited(_refreshLocationQuiet());
    });
  }

  @override
  void dispose() {
    _geoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationDecision() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _locationDecisionMade = prefs.getBool(_kLocationDecisionKey) ?? false;
    });
  }

  Future<void> _setLocationDecision(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationDecisionKey, true);
    if (!mounted) return;
    setState(() => _locationDecisionMade = true);
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    if (!_locationDecisionMade) {
      await _ensureLocationDecision();
    } else {
      await _tryGetLocationSilently();
    }
    if (mounted) await _search();
  }

  Future<void> _ensureLocationDecision() async {
    final has = await _tryGetLocation(interactivePrompt: true);
    if (!mounted) return;
    if (!has) setState(() { _lat = null; _lng = null; });
  }

  Future<void> _tryGetLocationSilently() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      await _maybePingProviderRendering(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await sm.listServiceCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<bool> _tryGetLocation({required bool interactivePrompt}) async {
    setState(() { _err = null; _loading = true; });
    try {
      if (interactivePrompt && mounted && !_locationDecisionMade) {
        final allow = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _LocationPermissionDialog(
            onDecision: (_) => _setLocationDecision(true),
          ),
        );
        if (allow != true) {
          await _setLocationDecision(true);
          setState(() { _err = null; _lat = null; _lng = null; });
          return false;
        }
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _err =
            'Location services are off. Enable GPS to sort by distance.');
        return false;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _err =
            'Location permission is blocked. Enable it in Settings.');
        await Geolocator.openAppSettings();
        return false;
      }
      if (perm == LocationPermission.denied) {
        setState(() => _err = 'Location permission denied. Showing best-rated services.');
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      await _maybePingProviderRendering(pos.latitude, pos.longitude);
      return true;
    } catch (e) {
      setState(() {
        _err = 'Could not read GPS. Searching without distance.';
        _lat = null;
        _lng = null;
      });
      return false;
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshLocationQuiet() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      await _maybePingProviderRendering(pos.latitude, pos.longitude);
      if (mounted) await _search();
    } catch (_) {}
  }

  Future<void> _maybePingProviderRendering(double lat, double lng) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    await sm.maybePingRenderingLocation(
        token: token, latitude: lat, longitude: lng);
  }

  Future<void> _search() async {
    setState(() { _err = null; _loading = true; });
    try {
      final results = await sm.searchServiceListings(
        latitude: _lat,
        longitude: _lng,
        categoryId: _categoryId,
        onlineOnly: _onlineOnly,
      );
      setState(() => _items = results);
    } catch (e) {
      setState(() => _err = 'Search failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(sm.ServiceListingRow row) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(listingId: row.id)),
    );
    if (mounted) await _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageGradientStart,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _search,
          color: _blue,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(
                  hasLocation: _lat != null,
                  errorMessage: _err,
                  onEnableLocation: () async {
                    await _tryGetLocation(interactivePrompt: true);
                    if (mounted) await _search();
                  },
                  onDismissError: () => setState(() => _err = null),
                  onOpenNotifications: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              ),

              // ── Filter strip ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _FilterStrip(
                  categories: _categories,
                  selectedCategoryId: _categoryId,
                  onlineOnly: _onlineOnly,
                  onCategoryChanged: (v) {
                    setState(() => _categoryId = v);
                    unawaited(_search());
                  },
                  onOnlineOnlyChanged: (v) {
                    setState(() => _onlineOnly = v);
                    unawaited(_search());
                  },
                ),
              ),

              // ── Result count ──────────────────────────────────────────
              if (_items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Text(
                      '${_items.length} service${_items.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500),
                    ),
                  ),
                ),

              // ── Empty state ───────────────────────────────────────────
              if (_items.isEmpty && !_loading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(onRefresh: _search),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final row = _items[i];
                      return _ListingCard(
                          row: row, onOpen: () => _openDetail(row));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.small(
              onPressed: () => _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic),
              backgroundColor: Colors.white,
              foregroundColor: _blue,
              elevation: 2,
              child: const Icon(Icons.arrow_upward),
            ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool hasLocation;
  final String? errorMessage;
  final VoidCallback onEnableLocation;
  final VoidCallback onDismissError;
  final VoidCallback onOpenNotifications;

  const _Header({
    required this.hasLocation,
    required this.errorMessage,
    required this.onEnableLocation,
    required this.onDismissError,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (!hasLocation) ...[
                _LocationChip(onTap: onEnableLocation),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Notifications',
                onPressed: onOpenNotifications,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(Icons.notifications_outlined, color: _blue, size: 24),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
                message: errorMessage!, onDismiss: onDismissError),
          ],
        ],
      ),
    );
  }
}

// ─── Filter strip ─────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  final List<sm.ServiceCategory> categories;
  final String? selectedCategoryId;
  final bool onlineOnly;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onOnlineOnlyChanged;

  const _FilterStrip({
    required this.categories,
    required this.selectedCategoryId,
    required this.onlineOnly,
    required this.onCategoryChanged,
    required this.onOnlineOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          // thin divider above strip
          Divider(height: 0, thickness: 0.5, color: _blueBorder),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length + 2, // All + categories + Online
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Chip(
                    label: 'All',
                    isSelected: selectedCategoryId == null && !onlineOnly,
                    onTap: () {
                      onCategoryChanged(null);
                      if (onlineOnly) onOnlineOnlyChanged(false);
                    },
                  );
                }
                if (index <= categories.length) {
                  final cat = categories[index - 1];
                  return _Chip(
                    label: cat.name,
                    isSelected: selectedCategoryId == cat.id,
                    onTap: () => onCategoryChanged(cat.id),
                  );
                }
                // Online only chip
                return _Chip(
                  label: 'Online only',
                  isSelected: onlineOnly,
                  leadingDot: true,
                  onTap: () => onOnlineOnlyChanged(!onlineOnly),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool leadingDot;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.leadingDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _blue : _blueBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : _blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Location chip ────────────────────────────────────────────────────────────

class _LocationChip extends StatelessWidget {
  final VoidCallback onTap;

  const _LocationChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _blueTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _blueBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 13, color: _blue),
            const SizedBox(width: 4),
            Text(
              'Enable location',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _blue),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: _blueTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blueBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: _blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13, color: _blue, height: 1.3)),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: _blue),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _blueTint, shape: BoxShape.circle),
              child: Icon(Icons.search_off_outlined,
                  size: 40, color: _blue.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            Text('No services found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _blue)),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your filters or check back later',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Listing card ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final sm.ServiceListingRow row;
  final VoidCallback onOpen;

  const _ListingCard({required this.row, required this.onOpen});

  Color _statusColor(String s) {
    if (s == 'ONLINE') return Colors.green.shade600;
    if (s == 'AWAY') return Colors.orange.shade700;
    return Colors.grey.shade500;
  }

  String? _responseLine(int sec) {
    if (sec <= 0) return null;
    if (sec < 45) return '~1m';
    if (sec < 3600) return '~${(sec / 60).round().clamp(1, 999)}m';
    final h = (sec / 3600).round().clamp(1, 999);
    return h == 1 ? '~1h' : '~${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final response = _responseLine(row.avgResponseTimeSec);

    return Hero(
      tag: 'listing_${row.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: _blueBorder.withOpacity(0.5), width: 0.5),
              boxShadow: [
                BoxShadow(
                    color: _blue.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cover image ───────────────────────────────────────
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        row.coverImageUrl != null
                            ? Image.network(row.coverImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _PlaceholderCover())
                            : _PlaceholderCover(),

                        // Category badge – bottom left
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              row.categoryName,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3),
                            ),
                          ),
                        ),

                        // Status badge – top right
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _statusColor(row.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  row.status,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(row.status)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Body ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _blue,
                            height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              row.providerLocationLine != null
                                  ? '${row.providerName} · ${row.providerLocationLine}'
                                  : row.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        row.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.45),
                      ),
                      const SizedBox(height: 12),

                      // ── Meta pills ──────────────────────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(
                            icon: Icons.star_rounded,
                            text:
                                '${row.ratingAvg.toStringAsFixed(1)} (${row.ratingCount})',
                          ),
                          if (row.distanceKm != null)
                            _MetaPill(
                              icon: Icons.near_me_outlined,
                              text:
                                  '${row.distanceKm!.toStringAsFixed(1)} km',
                            ),
                          if (response != null)
                            _MetaPill(
                              icon: Icons.bolt,
                              text: response,
                            ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Footer ──────────────────────────────────────
                      Row(
                        children: [
                          Text(
                            row.priceLabel,
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: _blue),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text('View',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 13)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios,
                                    size: 11, color: Colors.white),
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
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _blueTint,
      child: Center(
        child: Icon(Icons.image_outlined,
            color: _blue.withOpacity(0.25), size: 40),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _blueTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _blue),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
        ],
      ),
    );
  }
}

// ─── Location permission dialog ───────────────────────────────────────────────

class _LocationPermissionDialog extends StatelessWidget {
  final ValueChanged<bool> onDecision;

  const _LocationPermissionDialog({required this.onDecision});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _blueTint, shape: BoxShape.circle),
              child:
                  Icon(Icons.location_on_outlined, size: 32, color: _blue),
            ),
            const SizedBox(height: 20),
            Text('Use your location?',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                        fontWeight: FontWeight.w800, color: _blue)),
            const SizedBox(height: 8),
            Text(
              'We use your location to sort providers by distance. You can continue without it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  onDecision(true);
                  Navigator.pop(context, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Allow location',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  onDecision(false);
                  Navigator.pop(context, false);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Not now',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}