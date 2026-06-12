// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../api/service_marketplace_api.dart' as sm;
// import '../auth/auth_controller.dart';
// import '../theme/app_colors.dart';
// import '../theme/app_theme.dart';
// import 'marketplace_booking_detail_screen.dart';

// class MarketplaceBookingsScreen extends StatefulWidget {
//   const MarketplaceBookingsScreen({
//     super.key,
//     this.showTitle = true,
//     this.onBookingListChanged,
//     this.fixedTab,
//     this.onGoToExplore,
//   });

//   /// When embedded in [MarketplaceStoreScreen], hide the duplicate "Bookings" heading.
//   final bool showTitle;

//   /// Called after each successful booking list load (e.g. to refresh the Store tab badge).
//   final Future<void> Function()? onBookingListChanged;

//   /// When `'me'` or `'provider'`, only that list loads and the segmented control is hidden.
//   final String? fixedTab;

//   /// From shell when embedded in Store (empty "My bookings" → Browse services).
//   final VoidCallback? onGoToExplore;

//   @override
//   State<MarketplaceBookingsScreen> createState() => _MarketplaceBookingsScreenState();
// }

// class _MarketplaceBookingsScreenState extends State<MarketplaceBookingsScreen> {
//   bool _loading = true;
//   String? _err;
//   List<Map<String, dynamic>> _items = const [];
//   late String _tab; // me | provider

//   @override
//   void initState() {
//     super.initState();
//     assert(
//       widget.fixedTab == null || widget.fixedTab == 'me' || widget.fixedTab == 'provider',
//     );
//     _tab = widget.fixedTab ?? 'me';
//     WidgetsBinding.instance.addPostFrameCallback((_) => _load());
//   }

//   Future<void> _load() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     if (token == null) return;
//     setState(() {
//       _loading = true;
//       _err = null;
//     });
//     try {
//       final rows = _tab == 'me'
//           ? await sm.listMyServiceBookings(token: token)
//           : await sm.listProviderServiceBookings(token: token);
//       if (!mounted) return;
//       setState(() {
//         _items = rows;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _err = e.toString());
//     } finally {
//       if (mounted) setState(() => _loading = false);
//       final cb = widget.onBookingListChanged;
//       if (cb != null) unawaited(cb());
//     }
//   }

//   Future<void> _openDetail(String bookingId) async {
//     await Navigator.of(context).push(
//       MaterialPageRoute<void>(
//         builder: (_) => MarketplaceBookingDetailScreen(
//           bookingId: bookingId,
//           initialMode: _tab,
//         ),
//       ),
//     );
//     if (!mounted) return;
//     await _load();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthController>();
//     final token = auth.token;

//     return Stack(
//       children: [
//         const DecoratedBox(
//           decoration: BoxDecoration(gradient: AppColors.pageBackground),
//           child: SizedBox.expand(),
//         ),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             if (widget.showTitle || widget.fixedTab == null)
//               Padding(
//                 padding: EdgeInsets.fromLTRB(16, widget.showTitle ? 16 : 8, 16, 8),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (widget.showTitle) ...[
//                       Text('Bookings', style: displayHeading(context)),
//                       const SizedBox(height: 8),
//                     ],
//                     if (widget.fixedTab == null)
//                       Row(
//                         children: [
//                           Expanded(
//                             child: SegmentedButton<String>(
//                               segments: const [
//                                 ButtonSegment(value: 'me', label: Text('My bookings')),
//                                 ButtonSegment(
//                                   value: 'provider',
//                                   label: Text('I\'m provider'),
//                                 ),
//                               ],
//                               selected: {_tab},
//                               onSelectionChanged: (s) {
//                                 setState(() => _tab = s.first);
//                                 _load();
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//               ),
//             if (_err != null)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: _BookingListErrorBanner(message: _err!),
//               ),
//             Expanded(
//               child: token == null
//                   ? const Center(child: Text('Sign in to see bookings.'))
//                   : _loading
//                       ? const _BookingListSkeleton()
//                       : _items.isEmpty
//                           ? _BookingEmptyState(
//                               variant: _tab == 'me' ? 'my-bookings' : 'provider-bookings',
//                               onBrowseServices: _tab == 'me' ? widget.onGoToExplore : null,
//                             )
//                           : RefreshIndicator(
//                               onRefresh: _load,
//                               child: ListView.separated(
//                                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
//                                 itemCount: _items.length,
//                                 separatorBuilder: (_, _) => const SizedBox(height: 16),
//                                 itemBuilder: (context, i) {
//                                   final b = _items[i];
//                                   final id = '${b['id'] ?? ''}';
//                                   return _BookingStoreCard(
//                                     tab: _tab,
//                                     booking: b,
//                                     onViewBooking: () => _openDetail(id),
//                                   );
//                                 },
//                               ),
//                             ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// /// Parity with escrow_web `StoreBookingsListPanel` error banner.
// class _BookingListErrorBanner extends StatelessWidget {
//   const _BookingListErrorBanner({required this.message});

//   final String message;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFF1F2).withValues(alpha: 0.85),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFFFE4E6)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 6,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade700),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               message,
//               style: TextStyle(fontSize: 14, height: 1.35, color: Colors.red.shade800),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Parity with escrow_web loading skeleton for booking rows.
// class _BookingListSkeleton extends StatelessWidget {
//   const _BookingListSkeleton();

//   @override
//   Widget build(BuildContext context) {
//     return ListView.separated(
//       padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
//       itemCount: 3,
//       separatorBuilder: (_, _) => const SizedBox(height: 16),
//       itemBuilder: (_, _) => _skeletonCard(),
//     );
//   }

//   Widget _skeletonCard() {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFF1F5F9)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   height: 12,
//                   width: 96,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF1F5F9),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Container(
//                   height: 20,
//                   width: 200,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF1F5F9),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Container(
//                   height: 14,
//                   width: 120,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF1F5F9),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           Container(
//             height: 40,
//             width: 120,
//             decoration: BoxDecoration(
//               color: const Color(0xFFF1F5F9),
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Parity with escrow_web `EmptyState` inside `StoreBookingsListPanel`.
// class _BookingEmptyState extends StatelessWidget {
//   const _BookingEmptyState({
//     required this.variant,
//     this.onBrowseServices,
//   });

//   final String variant; // my-bookings | provider-bookings
//   final VoidCallback? onBrowseServices;

//   @override
//   Widget build(BuildContext context) {
//     final isMine = variant == 'my-bookings';
//     return Center(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//         child: Container(
//           constraints: const BoxConstraints(maxWidth: 420),
//           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
//           decoration: BoxDecoration(
//             color: Colors.white.withValues(alpha: 0.5),
//             borderRadius: BorderRadius.circular(24),
//             border: Border.all(color: const Color(0xFFE2E8F0)),
//           ),
//           child: Column(
//             children: [
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: BoxDecoration(
//                   color: AppColors.primaryColorBlack.withValues(alpha: 0.06),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Icon(
//                   Icons.calendar_today_outlined,
//                   size: 32,
//                   color: AppColors.primaryColorBlack.withValues(alpha: 0.55),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 isMine ? 'No bookings yet' : 'No provider bookings',
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF1E293B),
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 isMine
//                     ? 'You haven\'t booked any services yet. Browse the marketplace to find services you need.'
//                     : 'No one has booked your services yet. Keep your listings up to date to attract customers.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 14,
//                   height: 1.45,
//                   color: Colors.grey.shade600,
//                 ),
//               ),
//               if (isMine && onBrowseServices != null) ...[
//                 const SizedBox(height: 24),
//                 FilledButton.icon(
//                   style: FilledButton.styleFrom(
//                     backgroundColor: AppColors.primaryColorBlack,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     elevation: 3,
//                     shadowColor: AppColors.primaryColorBlack.withValues(alpha: 0.2),
//                   ),
//                   onPressed: onBrowseServices,
//                   icon: const Icon(Icons.search, size: 18),
//                   label: const Text('Browse services', style: TextStyle(fontWeight: FontWeight.w600)),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Parity with escrow_web `StatusBadge`.
// class _BookingStatusBadge extends StatelessWidget {
//   const _BookingStatusBadge({required this.status});

//   final String status;

//   @override
//   Widget build(BuildContext context) {
//     final normalized = status.toLowerCase();
//     late final Color bg;
//     late final Color fg;
//     late final Color dot;
//     if (normalized.contains('cancel')) {
//       bg = const Color(0xFFFFF1F2);
//       fg = const Color(0xFFB91C1C);
//       dot = const Color(0xFFF87171);
//     } else if (normalized.contains('reject')) {
//       bg = const Color(0xFFF8FAFC);
//       fg = const Color(0xFF334155);
//       dot = const Color(0xFF94A3B8);
//     } else if (normalized.contains('complete')) {
//       bg = const Color(0xFFEFF6FF);
//       fg = const Color(0xFF1D4ED8);
//       dot = const Color(0xFF60A5FA);
//     } else if (normalized.contains('confirm') ||
//         normalized.contains('accept') ||
//         normalized.contains('fund') ||
//         normalized.contains('progress')) {
//       bg = const Color(0xFFECFDF5);
//       fg = const Color(0xFF047857);
//       dot = const Color(0xFF34D399);
//     } else {
//       bg = const Color(0xFFFFFBEB);
//       fg = const Color(0xFFB45309);
//       dot = const Color(0xFFFBBF24);
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 6,
//             height: 6,
//             decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             status,
//             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
//           ),
//         ],
//       ),
//     );
//   }
// }

// String? _contactNameLine(sm.MarketplaceUserContact? u) {
//   if (u == null) return null;
//   final parts = [u.displayName?.trim(), u.fullName?.trim()].whereType<String>().where((s) => s.isNotEmpty);
//   if (parts.isEmpty) return null;
//   return parts.join(' · ');
// }

// /// Parity with escrow_web `BookingCard` + `ParticipantContactMini`.
// class _BookingStoreCard extends StatelessWidget {
//   const _BookingStoreCard({
//     required this.tab,
//     required this.booking,
//     required this.onViewBooking,
//   });

//   final String tab;
//   final Map<String, dynamic> booking;
//   final VoidCallback onViewBooking;

//   @override
//   Widget build(BuildContext context) {
//     final listing = booking['listing'] as Map<String, dynamic>?;
//     final title = (listing?['title'] as String?) ?? 'Service';
//     final cat = (listing?['category'] as Map<String, dynamic>?)?['name'] as String? ?? 'Service';
//     final status = '${booking['status'] ?? ''}';
//     final amount = '${booking['amount'] ?? '0'}';

//     final trans = (booking['participantContact'] ?? booking['participantTransparency']) as Map<String, dynamic>?;
//     final clientT = sm.MarketplaceUserContact.fromJson(trans?['client']);
//     final providerT = sm.MarketplaceUserContact.fromJson(trans?['provider']);

//     String? participantLine;
//     if (tab == 'me') {
//       final fromContact = _contactNameLine(providerT);
//       if (fromContact != null && fromContact.isNotEmpty) {
//         participantLine = fromContact;
//       } else {
//         final p = listing?['provider'] as Map<String, dynamic>?;
//         final dn = (p?['displayName'] as String?)?.trim();
//         if (dn != null && dn.isNotEmpty) participantLine = dn;
//       }
//     } else {
//       participantLine = _contactNameLine(clientT);
//     }

//     final content = Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Wrap(
//           spacing: 8,
//           runSpacing: 6,
//           crossAxisAlignment: WrapCrossAlignment.center,
//           children: [
//             Text(
//               cat.toUpperCase(),
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700,
//                 letterSpacing: 1.2,
//                 color: AppColors.primaryColorBlack,
//               ),
//             ),
//             Text('·', style: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.w600)),
//             _BookingStatusBadge(status: status),
//           ],
//         ),
//         const SizedBox(height: 10),
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             height: 1.25,
//             color: Color(0xFF0F172A),
//           ),
//         ),
//         const SizedBox(height: 10),
//         Row(
//           children: [
//             Icon(Icons.payments_outlined, size: 16, color: Colors.grey.shade400),
//             const SizedBox(width: 8),
//             Text(
//               'D$amount',
//               style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
//             ),
//           ],
//         ),
//         if (participantLine != null && participantLine.isNotEmpty) ...[
//           const SizedBox(height: 10),
//           RichText(
//             text: TextSpan(
//               style: TextStyle(fontSize: 14, height: 1.35, color: Colors.grey.shade600),
//               children: [
//                 TextSpan(text: tab == 'me' ? 'Provider: ' : 'Client: ', style: TextStyle(color: Colors.grey.shade400)),
//                 TextSpan(
//                   text: participantLine,
//                   style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ],
//     );

//     final viewBtn = FilledButton(
//       style: FilledButton.styleFrom(
//         backgroundColor: AppColors.primaryColorBlack,
//         foregroundColor: Colors.white,
//         elevation: 2,
//         shadowColor: AppColors.primaryColorBlack.withValues(alpha: 0.2),
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//       onPressed: onViewBooking,
//       child: const Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text('View booking', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
//           SizedBox(width: 6),
//           Icon(Icons.chevron_right, size: 18),
//         ],
//       ),
//     );

//     return Material(
//       color: Colors.transparent,
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: const Color(0xFFF1F5F9)),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.06),
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: LayoutBuilder(
//             builder: (context, c) {
//               final narrow = c.maxWidth < 520;
//               if (narrow) {
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     content,
//                     const SizedBox(height: 20),
//                     SizedBox(width: double.infinity, child: viewBtn),
//                   ],
//                 );
//               }
//               return Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Expanded(child: content),
//                   const SizedBox(width: 16),
//                   viewBtn,
//                 ],
//               );
//             },
//           ),
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
import '../theme/app_theme.dart';
import 'marketplace_booking_detail_screen.dart';

const _blue = AppColors.primaryColorBlack;
const _blueTint = Color(0xFFE8EBFA);
const _blueBorder = Color(0xFFB5BEF0);

class MarketplaceBookingsScreen extends StatefulWidget {
  const MarketplaceBookingsScreen({
    super.key,
    this.showTitle = true,
    this.onBookingListChanged,
    this.fixedTab,
    this.onGoToExplore,
  });

  final bool showTitle;
  final Future<void> Function()? onBookingListChanged;
  final String? fixedTab;
  final VoidCallback? onGoToExplore;

  @override
  State<MarketplaceBookingsScreen> createState() =>
      _MarketplaceBookingsScreenState();
}

class _MarketplaceBookingsScreenState extends State<MarketplaceBookingsScreen> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = const [];
  late String _tab;

  @override
  void initState() {
    super.initState();
    assert(
      widget.fixedTab == null ||
          widget.fixedTab == 'me' ||
          widget.fixedTab == 'provider',
    );
    _tab = widget.fixedTab ?? 'me';
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
      final rows = _tab == 'me'
          ? await sm.listMyServiceBookings(token: token)
          : await sm.listProviderServiceBookings(token: token);
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
      final cb = widget.onBookingListChanged;
      if (cb != null) unawaited(cb());
    }
  }

  Future<void> _openDetail(String bookingId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceBookingDetailScreen(
          bookingId: bookingId,
          initialMode: _tab,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthController>().token;

    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.pageBackground),
          child: SizedBox.expand(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showTitle || widget.fixedTab == null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  widget.showTitle ? 20 : 8,
                  16,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showTitle) ...[
                      Text(
                        'Bookings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _blue,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.fixedTab == null)
                      _SegmentedToggle(
                        value: _tab,
                        onChanged: (v) {
                          setState(() => _tab = v);
                          _load();
                        },
                      ),
                  ],
                ),
              ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ErrorBanner(message: _err!),
              ),
            if (!_loading && token != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _BookingsSummary(
                  items: _items,
                  isProvider: _tab == 'provider',
                ),
              ),
            Expanded(
              child: token == null
                  ? const Center(child: Text('Sign in to see bookings.'))
                  : _loading
                  ? const _Skeleton()
                  : _items.isEmpty
                  ? _EmptyState(
                      isMe: _tab == 'me',
                      onBrowse: _tab == 'me' ? widget.onGoToExplore : null,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _blue,
                      backgroundColor: Colors.white,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final b = _items[i];
                          final id = '${b['id'] ?? ''}';
                          return _BookingCard(
                            tab: _tab,
                            booking: b,
                            onView: () => _openDetail(id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BookingsSummary extends StatelessWidget {
  const _BookingsSummary({required this.items, required this.isProvider});

  final List<Map<String, dynamic>> items;
  final bool isProvider;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((b) {
      final s = '${b['status'] ?? ''}'.toUpperCase();
      return s.contains('PENDING') || s == 'ACCEPTED' || s == 'IN_PROGRESS';
    }).length;
    var total = 0.0;
    for (final b in items) {
      total += double.tryParse('${b['amount'] ?? '0'}') ?? 0;
    }
    return Row(
      children: [
        Expanded(
          child: _BookingMiniStat(
            label: isProvider ? 'Provider' : 'Mine',
            value: '${items.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BookingMiniStat(label: 'Pending', value: '$pending'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BookingMiniStat(
            label: isProvider ? 'Revenue' : 'Value',
            value: 'D${total.toStringAsFixed(0)}',
          ),
        ),
      ],
    );
  }
}

class _BookingMiniStat extends StatelessWidget {
  const _BookingMiniStat({required this.label, required this.value});

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

// ─── Segmented toggle ─────────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SegmentedToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blueBorder, width: 0.5),
      ),
      child: Row(
        children: [
          _Seg(
            label: 'My bookings',
            val: 'me',
            current: value,
            onTap: onChanged,
          ),
          const SizedBox(width: 4),
          _Seg(
            label: "I'm provider",
            val: 'provider',
            current: value,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final String val;
  final String current;
  final ValueChanged<String> onTap;

  const _Seg({
    required this.label,
    required this.val,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = val == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : _blue.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _blueTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blueBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 17, color: _blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: _blue, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => _skCard(),
    );
  }

  Widget _skCard() {
    final bar = (double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: _blueTint,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blueBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(80, 11),
                const SizedBox(height: 10),
                bar(200, 18),
                const SizedBox(height: 8),
                bar(120, 13),
              ],
            ),
          ),
          const SizedBox(width: 12),
          bar(110, 38),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isMe;
  final VoidCallback? onBrowse;
  const _EmptyState({required this.isMe, this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blueBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: _blue.withOpacity(0.06),
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
                  Icons.calendar_today_outlined,
                  size: 28,
                  color: _blue.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isMe ? 'No bookings yet' : 'No provider bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMe
                    ? "You haven't booked any services yet. Browse the marketplace to find services you need."
                    : 'No one has booked your services yet. Keep your listings up to date to attract customers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.grey.shade500,
                ),
              ),
              if (isMe && onBrowse != null) ...[
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
                    ),
                    onPressed: onBrowse,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text(
                      'Browse services',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final n = status.toLowerCase();
    late Color bg, fg, dot;
    if (n.contains('cancel')) {
      bg = const Color(0xFFFFF1F2);
      fg = const Color(0xFFB91C1C);
      dot = const Color(0xFFF87171);
    } else if (n.contains('reject')) {
      bg = const Color(0xFFF8FAFC);
      fg = const Color(0xFF334155);
      dot = const Color(0xFF94A3B8);
    } else if (n.contains('complete')) {
      bg = _blueTint;
      fg = _blue;
      dot = _blue.withOpacity(0.5);
    } else if (n.contains('confirm') ||
        n.contains('accept') ||
        n.contains('fund') ||
        n.contains('progress')) {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
      dot = const Color(0xFF34D399);
    } else {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
      dot = const Color(0xFFFBBF24);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────

String? _contactNameLine(sm.MarketplaceUserContact? u) {
  if (u == null) return null;
  final parts = [
    u.displayName?.trim(),
    u.fullName?.trim(),
  ].whereType<String>().where((s) => s.isNotEmpty);
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

class _BookingCard extends StatelessWidget {
  final String tab;
  final Map<String, dynamic> booking;
  final VoidCallback onView;

  const _BookingCard({
    required this.tab,
    required this.booking,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final listing = booking['listing'] as Map<String, dynamic>?;
    final title = (listing?['title'] as String?) ?? 'Service';
    final cat =
        (listing?['category'] as Map<String, dynamic>?)?['name'] as String? ??
        'Service';
    final status = '${booking['status'] ?? ''}';
    final amount = '${booking['amount'] ?? '0'}';

    final trans =
        (booking['participantContact'] ?? booking['participantTransparency'])
            as Map<String, dynamic>?;
    final clientT = sm.MarketplaceUserContact.fromJson(trans?['client']);
    final providerT = sm.MarketplaceUserContact.fromJson(trans?['provider']);

    String? participantLine;
    if (tab == 'me') {
      participantLine =
          _contactNameLine(providerT) ??
          (listing?['provider'] as Map<String, dynamic>?)?['displayName']
              as String?;
    } else {
      participantLine = _contactNameLine(clientT);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blueBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top row: category + status ────────────────────────────
            Row(
              children: [
                Text(
                  cat.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _blue,
                  ),
                ),
                const SizedBox(width: 8),
                Text('·', style: TextStyle(color: Colors.grey.shade300)),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),

            const SizedBox(height: 10),

            // ── Title ────────────────────────────────────────────────
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: _blue,
              ),
            ),

            const SizedBox(height: 10),

            // ── Amount + participant ──────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 15,
                  color: _blue.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'D$amount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ],
            ),

            if (participantLine != null && participantLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        children: [
                          TextSpan(
                            text: tab == 'me' ? 'Provider: ' : 'Client: ',
                          ),
                          TextSpan(
                            text: participantLine,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ── View button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: onView,
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text(
                  'View booking',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
