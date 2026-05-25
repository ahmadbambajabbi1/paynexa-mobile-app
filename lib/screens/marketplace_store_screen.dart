// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../api/service_marketplace_api.dart' as sm;
// import '../auth/auth_controller.dart';
// import '../theme/app_colors.dart';
// import 'marketplace_bookings_screen.dart';
// import 'marketplace_services_screen.dart';
// import 'products_screen.dart';

// /// Seller hub: Services, Products, My bookings, Provider bookings (parity with escrow_web Store).
// class MarketplaceStoreScreen extends StatefulWidget {
//   const MarketplaceStoreScreen({super.key, this.onGoToExplore});

//   /// Switches main shell to Explore (e.g. empty bookings "Browse services").
//   final VoidCallback? onGoToExplore;

//   @override
//   State<MarketplaceStoreScreen> createState() => _MarketplaceStoreScreenState();
// }

// class _MarketplaceStoreScreenState extends State<MarketplaceStoreScreen>
//     with SingleTickerProviderStateMixin {
//   late final TabController _tabController;
//   int? _myBookingBadge;
//   int? _providerBookingBadge;

//   static const _borderSlate = Color(0xFFE2E8F0);

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 4, vsync: this);
//     _tabController.addListener(_onTabChanged);
//     WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookingBadges());
//   }

//   void _onTabChanged() {
//     setState(() {});
//     if (_tabController.indexIsChanging) return;
//     if (_tabController.index == 2 || _tabController.index == 3) {
//       unawaited(_loadBookingBadges());
//     }
//   }

//   @override
//   void dispose() {
//     _tabController.removeListener(_onTabChanged);
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadBookingBadges() async {
//     final token = context.read<AuthController>().token;
//     if (token == null) return;
//     try {
//       final mine = await sm.listMyServiceBookings(token: token);
//       final provider = await sm.listProviderServiceBookings(token: token);
//       if (!mounted) return;
//       final myN = mine.length;
//       final provN = provider.length;
//       if (_myBookingBadge != myN || _providerBookingBadge != provN) {
//         setState(() {
//           _myBookingBadge = myN;
//           _providerBookingBadge = provN;
//         });
//       }
//     } catch (_) {
//       /* badge is optional */
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
//           child: _StoreModernTabs(
//             controller: _tabController,
//             myBookingCount: _myBookingBadge,
//             providerBookingCount: _providerBookingBadge,
//             borderColor: _borderSlate,
//           ),
//         ),
//         Expanded(
//           child: TabBarView(
//             controller: _tabController,
//             children: [
//               const Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 8),
//                 child: MarketplaceServicesScreen(),
//               ),
//               const Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 8),
//                 child: ProductsScreen(),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8),
//                 child: MarketplaceBookingsScreen(
//                   showTitle: false,
//                   fixedTab: 'me',
//                   onBookingListChanged: _loadBookingBadges,
//                   onGoToExplore: widget.onGoToExplore,
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 8),
//                 child: MarketplaceBookingsScreen(
//                   showTitle: false,
//                   fixedTab: 'provider',
//                   onBookingListChanged: _loadBookingBadges,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// /// One horizontal scrollable row of tabs (mobile-friendly); same chrome as escrow_web Store tabs container.
// class _StoreModernTabs extends StatelessWidget {
//   const _StoreModernTabs({
//     required this.controller,
//     required this.myBookingCount,
//     required this.providerBookingCount,
//     required this.borderColor,
//   });

//   final TabController controller;
//   final int? myBookingCount;
//   final int? providerBookingCount;
//   final Color borderColor;

//   @override
//   Widget build(BuildContext context) {
//     return DecoratedBox(
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.82),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: borderColor.withValues(alpha: 0.8)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 6,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.all(6),
//         child: Row(
//           children: [
//             _StoreTabTile(
//               index: 0,
//               controller: controller,
//               myBookingCount: myBookingCount,
//               providerBookingCount: providerBookingCount,
//             ),
//             const SizedBox(width: 4),
//             _StoreTabTile(
//               index: 1,
//               controller: controller,
//               myBookingCount: myBookingCount,
//               providerBookingCount: providerBookingCount,
//             ),
//             const SizedBox(width: 4),
//             _StoreTabTile(
//               index: 2,
//               controller: controller,
//               myBookingCount: myBookingCount,
//               providerBookingCount: providerBookingCount,
//             ),
//             const SizedBox(width: 4),
//             _StoreTabTile(
//               index: 3,
//               controller: controller,
//               myBookingCount: myBookingCount,
//               providerBookingCount: providerBookingCount,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Fixed width so horizontal scroll works; avoids [Expanded] inside unbounded horizontal layout.
// class _StoreTabTile extends StatelessWidget {
//   const _StoreTabTile({
//     required this.index,
//     required this.controller,
//     required this.myBookingCount,
//     required this.providerBookingCount,
//   });

//   final int index;
//   final TabController controller;
//   final int? myBookingCount;
//   final int? providerBookingCount;

//   static const double _chipWidth = 172;

//   @override
//   Widget build(BuildContext context) {
//     final active = controller.index == index;
//     late final IconData icon;
//     late final String label;
//     late final String description;
//     int? badge;
//     switch (index) {
//       case 0:
//         icon = Icons.work_outline;
//         label = 'Services';
//         description = 'Your service listings';
//         badge = null;
//       case 1:
//         icon = Icons.layers_outlined;
//         label = 'Products';
//         description = 'Your product catalog';
//         badge = null;
//       case 2:
//         icon = Icons.calendar_today_outlined;
//         label = 'My Bookings';
//         description = 'Bookings you made';
//         badge = myBookingCount;
//       case 3:
//         icon = Icons.people_alt_outlined;
//         label = 'Provider Bookings';
//         description = 'Bookings for your services';
//         badge = providerBookingCount;
//     }

//     return SizedBox(
//       width: _chipWidth,
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(12),
//           onTap: () => controller.animateTo(index),
//           child: Ink(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               color: active ? AppColors.gambianBlue : Colors.transparent,
//               boxShadow: active
//                   ? [
//                       BoxShadow(
//                         color: AppColors.gambianBlue.withValues(alpha: 0.25),
//                         blurRadius: 12,
//                         offset: const Offset(0, 4),
//                       ),
//                     ]
//                   : null,
//             ),
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(minHeight: 72),
//               child: Stack(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(
//                           icon,
//                           size: 18,
//                           color: active ? Colors.white : Colors.grey.shade400,
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       label,
//                                       maxLines: 2,
//                                       overflow: TextOverflow.ellipsis,
//                                       style: TextStyle(
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.w600,
//                                         letterSpacing: -0.2,
//                                         height: 1.15,
//                                         color: active ? Colors.white : const Color(0xFF64748B),
//                                       ),
//                                     ),
//                                   ),
//                                   if (badge != null && badge > 0) ...[
//                                     const SizedBox(width: 6),
//                                     _TabCountBadge(count: badge, onBlue: active),
//                                   ],
//                                 ],
//                               ),
//                               const SizedBox(height: 2),
//                               Text(
//                                 description,
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w400,
//                                   height: 1.2,
//                                   color: active ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade400,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (active)
//                     Positioned.fill(
//                       child: IgnorePointer(
//                         child: DecoratedBox(
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _TabCountBadge extends StatelessWidget {
//   const _TabCountBadge({required this.count, required this.onBlue});

//   final int count;
//   final bool onBlue;

//   @override
//   Widget build(BuildContext context) {
//     final text = count > 99 ? '99+' : '$count';
//     if (onBlue) {
//       return Container(
//         constraints: const BoxConstraints(minWidth: 20),
//         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(999),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.08),
//               blurRadius: 4,
//             ),
//           ],
//         ),
//         child: Text(
//           text,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w700,
//             color: AppColors.gambianBlue,
//             height: 1.1,
//           ),
//         ),
//       );
//     }
//     return Container(
//       constraints: const BoxConstraints(minWidth: 20),
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//       decoration: BoxDecoration(
//         color: AppColors.gambianBlue,
//         borderRadius: BorderRadius.circular(999),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.08),
//             blurRadius: 4,
//           ),
//         ],
//       ),
//       child: Text(
//         text,
//         textAlign: TextAlign.center,
//         style: const TextStyle(
//           fontSize: 11,
//           fontWeight: FontWeight.w700,
//           color: Colors.white,
//           height: 1.1,
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/service_marketplace_api.dart' as sm;
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import 'marketplace_bookings_screen.dart';
import 'marketplace_services_screen.dart';
import 'products_screen.dart';

const _blue = AppColors.gambianBlue;
const _blueTint = Color(0xFFE8EBFA);
const _blueBorder = Color(0xFFB5BEF0);

class MarketplaceStoreScreen extends StatefulWidget {
  const MarketplaceStoreScreen({super.key, this.onGoToExplore});
  final VoidCallback? onGoToExplore;

  @override
  State<MarketplaceStoreScreen> createState() => _MarketplaceStoreScreenState();
}

class _MarketplaceStoreScreenState extends State<MarketplaceStoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _myBookingBadge;
  int? _providerBookingBadge;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookingBadges());
  }

  void _onTabChanged() {
    setState(() {});
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 2 || _tabController.index == 3) {
      unawaited(_loadBookingBadges());
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingBadges() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final mine = await sm.listMyServiceBookings(token: token);
      final provider = await sm.listProviderServiceBookings(token: token);
      if (!mounted) return;
      final myN = mine.length;
      final provN = provider.length;
      if (_myBookingBadge != myN || _providerBookingBadge != provN) {
        setState(() {
          _myBookingBadge = myN;
          _providerBookingBadge = provN;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tab strip ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.pageGradientStart,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _blueBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: _blue.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(4, (i) {
                final gap = i < 4
                    ? const SizedBox(width: 4)
                    : const SizedBox.shrink();
                return Row(
                  children: [
                    _StoreTab(
                      index: i,
                      controller: _tabController,
                      myBadge: _myBookingBadge,
                      providerBadge: _providerBookingBadge,
                    ),
                    gap,
                  ],
                );
              }),
            ),
          ),
        ),

        // ── Tab views ─────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: MarketplaceServicesScreen(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: ProductsScreen(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MarketplaceBookingsScreen(
                  showTitle: false,
                  fixedTab: 'me',
                  onBookingListChanged: _loadBookingBadges,
                  onGoToExplore: widget.onGoToExplore,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MarketplaceBookingsScreen(
                  showTitle: false,
                  fixedTab: 'provider',
                  onBookingListChanged: _loadBookingBadges,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreTab extends StatelessWidget {
  const _StoreTab({
    required this.index,
    required this.controller,
    required this.myBadge,
    required this.providerBadge,
  });

  final int index;
  final TabController controller;
  final int? myBadge;
  final int? providerBadge;

  static const double _w = 168;

  @override
  Widget build(BuildContext context) {
    final active = controller.index == index;

    late final IconData icon;
    late final String label;
    late final String sub;
    int? badge;

    switch (index) {
      case 0:
        icon = Icons.work_outline;
        label = 'Services';
        sub = 'Your listings';
      case 1:
        icon = Icons.layers_outlined;
        label = 'Products';
        sub = 'Your catalog';
      case 2:
        icon = Icons.calendar_today_outlined;
        label = 'My Bookings';
        sub = 'Bookings you made';
        badge = myBadge;
      case 3:
        icon = Icons.people_alt_outlined;
        label = 'Provider';
        sub = 'Bookings for you';
        badge = providerBadge;
    }

    return SizedBox(
      width: _w,
      child: GestureDetector(
        onTap: () => controller.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: active ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? Colors.white : _blue.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : _blue,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (badge != null && badge > 0) ...[
                          const SizedBox(width: 4),
                          _Badge(count: badge, onBlue: active),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: active
                            ? Colors.white.withOpacity(0.65)
                            : _blue.withOpacity(0.45),
                      ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.onBlue});
  final int count;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: onBlue ? Colors.white : _blue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: onBlue ? _blue : Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}
