// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../api/maps_place_client.dart';
// import '../api/service_marketplace_api.dart' as sm;
// import '../auth/auth_controller.dart';
// import '../config/constants.dart';
// import '../theme/app_colors.dart';

// /// Hides scrollbar overlays for horizontal thumbnail strips (esp. desktop/web).
// class _NoScrollbarBehavior extends ScrollBehavior {
//   const _NoScrollbarBehavior();

//   @override
//   Widget buildScrollbar(
//       BuildContext context, Widget child, ScrollableDetails details) {
//     return child;
//   }
// }

// class ServiceDetailScreen extends StatefulWidget {
//   const ServiceDetailScreen({super.key, required this.listingId});

//   final String listingId;

//   @override
//   State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
// }

// class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
//   bool _loading = true;
//   String? _err;
//   sm.ServiceListingDetailResult? _detail;
//   final _agreedAmountCtrl = TextEditingController();
//   final _locationSearchCtrl = TextEditingController();
//   final _directionsNotesCtrl = TextEditingController();
//   final _jobNotesCtrl = TextEditingController();
//   MapsPickedPlace? _pickedLocation;
//   List<MapsPlacePrediction> _predictions = const [];
//   bool _mapsBackendReady = true;
//   bool _mapsReadyChecked = false;
//   bool _locBusy = false;
//   bool _searchBusy = false;
//   Timer? _searchDebounce;
//   AuthController? _authListen;

//   @override
//   void initState() {
//     super.initState();
//     _locationSearchCtrl.addListener(_onLocationSearchChanged);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       final auth = context.read<AuthController>();
//       _authListen = auth;
//       auth.addListener(_onAuthChanged);
//       _load();
//       _refreshMapsReady();
//     });
//   }

//   Future<void> _refreshMapsReady() async {
//     final ok = await isMapsSearchBackendReady();
//     if (!mounted) return;
//     setState(() {
//       _mapsBackendReady = ok;
//       _mapsReadyChecked = true;
//     });
//   }

//   void _onLocationSearchChanged() {
//     _searchDebounce?.cancel();
//     final q = _locationSearchCtrl.text;
//     if (q.trim().length < 2) {
//       setState(() => _predictions = const []);
//       return;
//     }
//     if (_pickedLocation != null) return;
//     _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
//       if (!_mapsBackendReady) return;
//       setState(() => _searchBusy = true);
//       try {
//         final list = await mapsAutocompletePlaces(q);
//         if (!mounted) return;
//         setState(() => _predictions = list);
//       } finally {
//         if (mounted) setState(() => _searchBusy = false);
//       }
//     });
//   }

//   Future<void> _pickPrediction(MapsPlacePrediction pred) async {
//     setState(() => _predictions = const []);
//     FocusScope.of(context).unfocus();
//     final resolved = await mapsResolvePlace(pred);
//     if (!mounted) return;
//     if (resolved == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Could not use that suggestion. Try another.')),
//       );
//       return;
//     }
//     setState(() {
//       _pickedLocation = resolved;
//       _locationSearchCtrl.clear();
//     });
//   }

//   void _clearPickedLocation() {
//     setState(() {
//       _pickedLocation = null;
//       _predictions = const [];
//     });
//   }

//   void _onAuthChanged() {
//     if (mounted) _load();
//   }

//   @override
//   void dispose() {
//     _searchDebounce?.cancel();
//     _locationSearchCtrl.removeListener(_onLocationSearchChanged);
//     _authListen?.removeListener(_onAuthChanged);
//     _agreedAmountCtrl.dispose();
//     _locationSearchCtrl.dispose();
//     _directionsNotesCtrl.dispose();
//     _jobNotesCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _useCurrentLocation() async {
//     if (!_mapsBackendReady) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Location search is not available here.')),
//       );
//       return;
//     }
//     setState(() => _locBusy = true);
//     try {
//       var permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//       if (permission == LocationPermission.deniedForever ||
//           permission == LocationPermission.denied) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Location permission is required for GPS booking. Try searching instead.'),
//           ),
//         );
//         setState(() => _locBusy = false);
//         return;
//       }
//       final pos = await Geolocator.getCurrentPosition(
//         locationSettings: const LocationSettings(
//           accuracy: LocationAccuracy.bestForNavigation,
//         ),
//       );
//       final rev = await mapsReverseGeocode(pos.latitude, pos.longitude);
//       if (!mounted) return;
//       if (rev == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Could not translate this position into an address. Try searching.'),
//           ),
//         );
//         return;
//       }
//       setState(() => _pickedLocation = rev);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Location was denied or could not be read. Try searching instead.'),
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _locBusy = false);
//     }
//   }

//   Future<void> _load() async {
//     final auth = context.read<AuthController>();
//     setState(() {
//       _loading = true;
//       _err = null;
//     });
//     try {
//       final d = await sm.getServiceListing(
//         id: widget.listingId,
//         token: auth.token,
//       );
//       if (!mounted) return;
//       setState(() {
//         _detail = d;
//         _err = null;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _err = e.toString());
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   Future<void> _book() async {
//     final auth = context.read<AuthController>();
//     final token = auth.token;
//     final detail = _detail;
//     if (token == null || detail == null || detail.viewerIsOwner) return;
//     final when = DateTime.now();
//     double? agreedAmount;
//     if (detail.priceType == 'RANGE') {
//       final raw = _agreedAmountCtrl.text.trim();
//       final parsed = double.tryParse(raw);
//       if (parsed == null || parsed <= 0) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Enter an agreed amount for this range service.')),
//         );
//         return;
//       }
//       final min = double.tryParse('${detail.raw['priceMin'] ?? ''}');
//       final max = double.tryParse('${detail.raw['priceMax'] ?? ''}');
//       if (min != null && parsed < min) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Amount must be at least D${min.toStringAsFixed(0)}.')),
//         );
//         return;
//       }
//       if (max != null && parsed > max) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Amount must be at most D${max.toStringAsFixed(0)}.')),
//         );
//         return;
//       }
//       agreedAmount = parsed;
//     }
//     final picked = _pickedLocation;
//     if (picked == null ||
//         picked.formattedAddress.trim().length < 8 ||
//         !picked.lat.isFinite ||
//         !picked.lng.isFinite) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             'Pick where the service should happen — search or use your current location.',
//           ),
//         ),
//       );
//       return;
//     }

//     try {
//       await sm.createBooking(
//         token: token,
//         listingId: widget.listingId,
//         scheduledAt: when,
//         agreedAmount: agreedAmount,
//         notes:
//             _jobNotesCtrl.text.trim().isEmpty ? null : _jobNotesCtrl.text.trim(),
//         serviceLatitude: picked.lat,
//         serviceLongitude: picked.lng,
//         serviceLocationLabel: picked.formattedAddress.trim(),
//         serviceGooglePlaceId: picked.placeId,
//         serviceAddressText: _directionsNotesCtrl.text.trim().isEmpty
//             ? null
//             : _directionsNotesCtrl.text.trim(),
//       );
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Booking created. Open Bookings to continue service delivery.')),
//       );
//       Navigator.of(context).pop(true);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Booking failed: ${e.toString()}')),
//       );
//     }
//   }

//   Color _statusColor(String s) {
//     if (s == 'ONLINE') return Colors.green.shade600;
//     if (s == 'AWAY') return Colors.orange.shade700;
//     return Colors.grey.shade600;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final token = context.watch<AuthController>().token;
//     return Scaffold(
//       appBar: AppBar(
//         title: Text.rich(
//           TextSpan(
//             children: [
//               TextSpan(
//                 text: kAppName,
//                 style: TextStyle(
//                   fontSize: 16,
//                   letterSpacing: -0.35,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.grey.shade900,
//                   decoration: TextDecoration.none,
//                 ),
//               ),
//               TextSpan(
//                 text: ' $kAppNameRegion',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w800,
//                   letterSpacing: 0.2,
//                   color: AppColors.primaryColorBlack,
//                   decoration: TextDecoration.none,
//                 ),
//               ),
//             ],
//           ),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//           textAlign: TextAlign.center,
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           tooltip: 'All services',
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: Stack(
//         children: [
//           const DecoratedBox(
//             decoration: BoxDecoration(gradient: AppColors.pageBackground),
//             child: SizedBox.expand(),
//           ),
//           if (_loading)
//             const Center(child: CircularProgressIndicator())
//           else if (_err != null)
//             Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Text(_err!, style: TextStyle(color: Colors.red.shade800)),
//               ),
//             )
//           else if (_detail != null)
//             _buildBody(context, _detail!, token),
//         ],
//       ),
//     );
//   }

//   Widget _buildBody(BuildContext context, sm.ServiceListingDetailResult d, String? token) {
//     final category =
//         (d.raw['category'] as Map<String, dynamic>?)?['name'] as String? ??
//             'Service';
//     final initials = () {
//       final n = d.sellerPublicName.trim();
//       final parts =
//           n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
//       if (parts.length >= 2) {
//         return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
//       }
//       if (parts.isNotEmpty && parts.first.length >= 2) {
//         return parts.first.substring(0, 2).toUpperCase();
//       }
//       if (parts.isNotEmpty) return parts.first[0].toUpperCase();
//       return '?';
//     }();

//     final coverUrl = d.coverUrl;
//     final thumbUrls =
//         coverUrl != null ? d.galleryUrls.where((u) => u != coverUrl).toList() : d.galleryUrls;
//     final reviews = d.reviewsRows;
//     final providerLoc = () {
//       final p = d.provider;
//       final loc = p['location'];
//       if (loc is! Map) return null;
//       final addressText = (loc['addressText'] as String?)?.trim();
//       final region = (loc['region'] as String?)?.trim();
//       final parts = <String>[];
//       if (addressText != null && addressText.isNotEmpty) parts.add(addressText);
//       if (region != null && region.isNotEmpty) parts.add(region);
//       final line = parts.join(' · ').trim();
//       return line.length >= 2 ? line : null;
//     }();
//     final providerLocLatLng = () {
//       final p = d.provider;
//       final loc = p['location'];
//       if (loc is! Map) return null;
//       final lat = loc['latitude'];
//       final lng = loc['longitude'];
//       if (lat is! num || lng is! num) return null;
//       final la = lat.toDouble();
//       final ln = lng.toDouble();
//       if (!la.isFinite || !ln.isFinite) return null;
//       return (la, ln);
//     }();

//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
//       children: [
//         Text(
//           d.sellerPublicName,
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
//         ),
//         Row(
//           children: [
//             Text('★ ${d.providerRating.toStringAsFixed(1)}',
//                 style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
//             const SizedBox(width: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//               decoration: BoxDecoration(
//                 color: _statusColor(d.providerStatus).withValues(alpha: 0.14),
//                 borderRadius: BorderRadius.circular(999),
//               ),
//               child: Text(
//                 d.providerStatus,
//                 style: TextStyle(
//                   fontWeight: FontWeight.w700,
//                   fontSize: 11,
//                   color: _statusColor(d.providerStatus),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               alignment: Alignment.center,
//               height: 56,
//               width: 56,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: AppColors.primaryColorBlack.withValues(alpha: 0.08),
//                 border: Border.all(color: AppColors.primaryColorBlack.withValues(alpha: 0.22)),
//               ),
//               child: Text(
//                 initials,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: AppColors.primaryColorBlack,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     d.title,
//                     style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     category.toUpperCase(),
//                     style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.primaryColorBlack),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 22),
//         const Divider(height: 1),
//         const SizedBox(height: 14),
//         Text(d.description, style: TextStyle(height: 1.45, fontSize: 14, color: Colors.grey.shade800)),
//         if (providerLoc != null) ...[
//           const SizedBox(height: 18),
//           Card(
//             child: Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.location_on_outlined, color: Colors.grey.shade700, size: 18),
//                       const SizedBox(width: 8),
//                       const Text('Provider location', style: TextStyle(fontWeight: FontWeight.w800)),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Text(providerLoc, style: TextStyle(color: Colors.grey.shade800)),
//                   if (providerLocLatLng != null) ...[
//                     const SizedBox(height: 8),
//                     TextButton.icon(
//                       onPressed: () async {
//                         final (la, ln) = providerLocLatLng;
//                         final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$la,$ln')}';
//                         final uri = Uri.parse(url);
//                         if (await canLaunchUrl(uri)) {
//                           await launchUrl(uri, mode: LaunchMode.externalApplication);
//                         }
//                       },
//                       icon: const Icon(Icons.map_outlined, size: 18),
//                       label: const Text('Open in Maps'),
//                       style: TextButton.styleFrom(foregroundColor: AppColors.primaryColorBlack),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ],
//         const SizedBox(height: 26),
//         Text(
//           'Gallery',
//           style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
//         ),
//         const SizedBox(height: 10),
//         if (coverUrl != null)
//           ClipRRect(
//             borderRadius: BorderRadius.circular(14),
//             child: AspectRatio(
//               aspectRatio: 16 / 9,
//               child: Image.network(
//                 coverUrl,
//                 fit: BoxFit.cover,
//                 errorBuilder: (_, __, ___) => ColoredBox(
//                   color: Colors.grey.shade300,
//                   child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade600),
//                 ),
//               ),
//             ),
//           )
//         else
//           Padding(
//             padding: const EdgeInsets.only(bottom: 4),
//             child: Text(
//               thumbUrls.isEmpty ? 'No cover image yet.' : 'No cover — showing gallery only.',
//               style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
//             ),
//           ),
//         if (thumbUrls.isNotEmpty) ...[
//           const SizedBox(height: 12),
//           SizedBox(
//             height: 96,
//             child: ScrollConfiguration(
//               behavior: const _NoScrollbarBehavior(),
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 physics: const BouncingScrollPhysics(),
//                 itemCount: thumbUrls.length,
//                 separatorBuilder: (_, __) => const SizedBox(width: 12),
//                 itemBuilder: (context, i) {
//                   final url = thumbUrls[i];
//                   return ClipRRect(
//                     borderRadius: BorderRadius.circular(12),
//                     child: SizedBox(
//                       width: 136,
//                       child: Image.network(
//                         url,
//                         fit: BoxFit.cover,
//                         errorBuilder: (_, __, ___) => ColoredBox(color: Colors.grey.shade300),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//         const SizedBox(height: 28),
//         Text(
//           'Reviews',
//           style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
//         ),
//         const SizedBox(height: 10),
//         if (reviews.isEmpty)
//           Text('No reviews yet for this service.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
//         else
//           ...reviews.take(15).map(
//                 (rev) => Card(
//                   margin: const EdgeInsets.only(bottom: 10),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Row(
//                               children: List.generate(5, (i) {
//                                 final r =
//                                     rev['rating'] is num ? (rev['rating'] as num).round() : 0;
//                                 return Icon(
//                                   i < r ? Icons.star_rounded : Icons.star_outline_rounded,
//                                   color: Colors.amber.shade700,
//                                   size: 18,
//                                 );
//                               }),
//                             ),
//                             Text(
//                               rev['createdAt'] != null ? '${rev['createdAt']}' : '',
//                               style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ],
//                         ),
//                         if ((rev['comment']?.toString() ?? '').trim().isNotEmpty) ...[
//                           const SizedBox(height: 8),
//                           Text(rev['comment'].toString().trim(), style: TextStyle(height: 1.35, color: Colors.grey.shade800)),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//         const Divider(height: 32),
//         Text(d.priceLabel, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
//         if (!d.viewerIsOwner && d.priceType == 'RANGE') ...[
//           const SizedBox(height: 10),
//           TextField(
//             controller: _agreedAmountCtrl,
//             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//             decoration: const InputDecoration(
//               labelText: 'Agreed amount (GMD)',
//               hintText: 'Enter amount within range',
//             ),
//           ),
//         ],
//         if (!d.viewerIsOwner) ...[
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               Icon(Icons.location_on_outlined, color: Colors.grey.shade700, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 'Service location',
//                 style:
//                     Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'Search or use your current location',
//             style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
//           ),
//           const SizedBox(height: 12),
//           if (!_mapsReadyChecked)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 8),
//               child: LinearProgressIndicator(
//                 minHeight: 2,
//                 color: AppColors.primaryColorBlack,
//                 backgroundColor: Colors.grey.shade200,
//               ),
//             )
//           else if (kMapsWebBaseUrl.trim().isNotEmpty && !_mapsBackendReady)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 8),
//               child: Text(
//                 'Location search is not available. Check MAPS_WEB_BASE_URL maps setup, '
//                 'or omit it to use OpenStreetMap search.',
//                 style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
//               ),
//             ),
//           if (_pickedLocation != null) ...[
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(14),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.place_outlined, color: AppColors.primaryColorBlack, size: 22),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'SELECTED LOCATION',
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   letterSpacing: 0.9,
//                                   fontWeight: FontWeight.w800,
//                                   color: Colors.grey.shade600,
//                                 ),
//                               ),
//                               const SizedBox(height: 6),
//                               Text(
//                                 _pickedLocation!.formattedAddress,
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   height: 1.35,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.grey.shade900,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         TextButton(
//                           onPressed: _clearPickedLocation,
//                           child: const Text('Remove'),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ] else ...[
//             TextField(
//               controller: _locationSearchCtrl,
//               enabled: _mapsBackendReady,
//               decoration: InputDecoration(
//                 prefixIcon: _searchBusy
//                     ? const Padding(
//                         padding: EdgeInsets.all(12),
//                         child: SizedBox(
//                           width: 20,
//                           height: 20,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         ),
//                       )
//                     : const Icon(Icons.search),
//                 hintText: 'Search for an address or place…',
//                 labelText: 'Search',
//               ),
//             ),
//             if (_predictions.isNotEmpty) ...[
//               const SizedBox(height: 8),
//               Card(
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: ConstrainedBox(
//                   constraints: const BoxConstraints(maxHeight: 240),
//                   child: ListView.separated(
//                     shrinkWrap: true,
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     itemCount: _predictions.length,
//                     separatorBuilder: (_, __) =>
//                         Divider(height: 1, color: Colors.grey.shade100),
//                     itemBuilder: (context, i) {
//                       final p = _predictions[i];
//                       return ListTile(
//                         dense: true,
//                         title: Text(
//                           p.description,
//                           maxLines: 3,
//                           overflow: TextOverflow.ellipsis,
//                           style:
//                               Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
//                         ),
//                         onTap: () => _pickPrediction(p),
//                       );
//                     },
//                   ),
//                 ),
//               ),
//             ],
//             const SizedBox(height: 10),
//             OutlinedButton.icon(
//               style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryColorBlack),
//               onPressed: (!_mapsBackendReady || _locBusy) ? null : _useCurrentLocation,
//               icon: _locBusy
//                   ? SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: AppColors.primaryColorBlack,
//                       ),
//                     )
//                   : const Icon(Icons.my_location_outlined),
//               label: Text(_locBusy ? 'Locating…' : 'Use current location'),
//             ),
//           ],
//           const SizedBox(height: 14),
//           TextField(
//             controller: _directionsNotesCtrl,
//             maxLines: 3,
//             decoration: const InputDecoration(
//               labelText: 'Extra directions (optional)',
//               hintText: 'Floor, gate colour, whom to ask for…',
//               alignLabelWithHint: true,
//             ),
//           ),
//           const SizedBox(height: 12),
//           TextField(
//             controller: _jobNotesCtrl,
//             maxLines: 3,
//             decoration: const InputDecoration(
//               labelText: 'Job notes (optional)',
//               hintText: 'Timeline, tools you will provide…',
//               alignLabelWithHint: true,
//             ),
//           ),
//         ],
//         if (d.providerContact != null) ...[
//           const SizedBox(height: 20),
//           Text(
//             'Provider',
//             style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
//           ),
//           const SizedBox(height: 8),
//           _ProviderContactCard(u: d.providerContact!),
//         ],
//         const SizedBox(height: 24),
//         if (d.viewerIsOwner)
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey.shade300),
//               color: Colors.white.withValues(alpha: 0.9),
//             ),
//             child: Text(
//               'This is your listing — guests complete booking below with escrow.',
//               style: TextStyle(color: Colors.grey.shade800),
//             ),
//           )
//         else ...[
//           FilledButton.icon(
//             style: FilledButton.styleFrom(
//               minimumSize: const Size.fromHeight(48),
//               backgroundColor: AppColors.primaryColorBlack,
//               foregroundColor: Colors.white,
//             ),
//             onPressed: token == null ? null : _book,
//             icon: const Icon(Icons.book_online_outlined),
//             label: Text(token == null ? 'Sign in to book' : 'Request booking'),
//           ),
//         ],
//       ],
//     );
//   }
// }

// class _ProviderContactCard extends StatelessWidget {
//   const _ProviderContactCard({required this.u});

//   final sm.MarketplaceUserContact u;

//   @override
//   Widget build(BuildContext context) {
//     final name = u.displayName ?? u.fullName ?? 'Provider';
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         color: Colors.white.withValues(alpha: 0.9),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
//           if (u.phone != null && u.phone!.isNotEmpty) ...[
//             const SizedBox(height: 6),
//             TextButton.icon(
//               onPressed: () async {
//                 final uri = Uri.parse('tel:${u.phone}');
//                 if (await canLaunchUrl(uri)) await launchUrl(uri);
//               },
//               icon: const Icon(Icons.phone_outlined, size: 18),
//               label: Text(u.phone!),
//               style: TextButton.styleFrom(foregroundColor: AppColors.primaryColorBlack),
//             ),
//           ],
//           if (u.email != null && u.email!.isNotEmpty)
//             TextButton.icon(
//               onPressed: () async {
//                 final uri = Uri.parse('mailto:${u.email}');
//                 if (await canLaunchUrl(uri)) await launchUrl(uri);
//               },
//               icon: const Icon(Icons.email_outlined, size: 18),
//               label: Text(u.email!, style: const TextStyle(fontSize: 14)),
//               style: TextButton.styleFrom(foregroundColor: AppColors.primaryColorBlack),
//             ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/maps_place_client.dart';
import '../api/service_marketplace_api.dart' as sm;
import '../auth/auth_controller.dart';
import '../config/constants.dart';
import '../theme/app_colors.dart';

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _loading = true;
  String? _err;
  sm.ServiceListingDetailResult? _detail;
  final _agreedAmountCtrl = TextEditingController();
  final _locationSearchCtrl = TextEditingController();
  final _directionsNotesCtrl = TextEditingController();
  final _jobNotesCtrl = TextEditingController();
  MapsPickedPlace? _pickedLocation;
  List<MapsPlacePrediction> _predictions = const [];
  bool _mapsBackendReady = true;
  bool _mapsReadyChecked = false;
  bool _locBusy = false;
  bool _searchBusy = false;
  Timer? _searchDebounce;
  AuthController? _authListen;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _locationSearchCtrl.addListener(_onLocationSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      _authListen = auth;
      auth.addListener(_onAuthChanged);
      _load();
      _refreshMapsReady();
    });
  }

  Future<void> _refreshMapsReady() async {
    final ok = await isMapsSearchBackendReady();
    if (!mounted) return;
    setState(() {
      _mapsBackendReady = ok;
      _mapsReadyChecked = true;
    });
  }

  void _onLocationSearchChanged() {
    _searchDebounce?.cancel();
    final q = _locationSearchCtrl.text;
    if (q.trim().length < 2) {
      setState(() => _predictions = const []);
      return;
    }
    if (_pickedLocation != null) return;
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      if (!_mapsBackendReady) return;
      setState(() => _searchBusy = true);
      try {
        final list = await mapsAutocompletePlaces(q);
        if (!mounted) return;
        setState(() => _predictions = list);
      } finally {
        if (mounted) setState(() => _searchBusy = false);
      }
    });
  }

  Future<void> _pickPrediction(MapsPlacePrediction pred) async {
    setState(() => _predictions = const []);
    FocusScope.of(context).unfocus();
    final resolved = await mapsResolvePlace(pred);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not use that suggestion. Try another.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _pickedLocation = resolved;
      _locationSearchCtrl.clear();
    });
  }

  void _clearPickedLocation() {
    setState(() {
      _pickedLocation = null;
      _predictions = const [];
    });
  }

  void _onAuthChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _locationSearchCtrl.removeListener(_onLocationSearchChanged);
    _authListen?.removeListener(_onAuthChanged);
    _agreedAmountCtrl.dispose();
    _locationSearchCtrl.dispose();
    _directionsNotesCtrl.dispose();
    _jobNotesCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (!_mapsBackendReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location search is not available here.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _locBusy = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required for GPS booking. Try searching instead.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _locBusy = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      final rev = await mapsReverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (rev == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not translate this position into an address. Try searching.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() => _pickedLocation = rev);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location was denied or could not be read. Try searching instead.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final d = await sm.getServiceListing(
        id: widget.listingId,
        token: auth.token,
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    final detail = _detail;
    if (token == null || detail == null || detail.viewerIsOwner) return;
    final when = DateTime.now();
    double? agreedAmount;
    if (detail.priceType == 'RANGE') {
      final raw = _agreedAmountCtrl.text.trim();
      final parsed = double.tryParse(raw);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter an agreed amount for this range service.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final min = double.tryParse('${detail.raw['priceMin'] ?? ''}');
      final max = double.tryParse('${detail.raw['priceMax'] ?? ''}');
      if (min != null && parsed < min) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount must be at least D${min.toStringAsFixed(0)}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (max != null && parsed > max) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Amount must be at most D${max.toStringAsFixed(0)}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      agreedAmount = parsed;
    }
    final picked = _pickedLocation;
    if (picked == null ||
        picked.formattedAddress.trim().length < 8 ||
        !picked.lat.isFinite ||
        !picked.lng.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick where the service should happen — search or use your current location.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await sm.createBooking(
        token: token,
        listingId: widget.listingId,
        scheduledAt: when,
        agreedAmount: agreedAmount,
        notes: _jobNotesCtrl.text.trim().isEmpty
            ? null
            : _jobNotesCtrl.text.trim(),
        serviceLatitude: picked.lat,
        serviceLongitude: picked.lng,
        serviceLocationLabel: picked.formattedAddress.trim(),
        serviceGooglePlaceId: picked.placeId,
        serviceAddressText: _directionsNotesCtrl.text.trim().isEmpty
            ? null
            : _directionsNotesCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Booking created. Open Bookings to continue service delivery.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _statusColor(String s) {
    if (s == 'ONLINE') return Colors.green.shade600;
    if (s == 'AWAY') return Colors.orange.shade700;
    return Colors.grey.shade600;
  }

  String? _formatAvgResponse(int seconds) {
    if (seconds <= 0) return null;
    if (seconds < 45) return 'usually within a minute';
    if (seconds < 3600) {
      final minutes = (seconds / 60).round().clamp(1, 59);
      return 'about $minutes min';
    }
    final hours = (seconds / 3600).round();
    return hours <= 1 ? 'about 1 hour' : 'about $hours hours';
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthController>().token;
    return Scaffold(
      backgroundColor: AppColors.pageGradientStart,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_err != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _err!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryColorBlack,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_detail != null)
            _buildBody(context, _detail!, token),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    sm.ServiceListingDetailResult d,
    String? token,
  ) {
    final category =
        (d.raw['category'] as Map<String, dynamic>?)?['name'] as String? ??
        'Service';
    final initials = () {
      final n = d.sellerPublicName.trim();
      final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2)
        return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
      if (parts.isNotEmpty && parts.first.length >= 2)
        return parts.first.substring(0, 2).toUpperCase();
      if (parts.isNotEmpty) return parts.first[0].toUpperCase();
      return '?';
    }();

    final coverUrl = d.coverUrl;
    final thumbUrls = coverUrl != null
        ? d.galleryUrls.where((u) => u != coverUrl).toList()
        : d.galleryUrls;
    final reviews = d.reviewsRows;
    final responseHint = _formatAvgResponse(d.providerAvgResponseTimeSec);
    final providerLoc = d.providerLocationLine;
    final providerLocLatLng = () {
      final p = d.provider;
      final loc = p['location'];
      if (loc is! Map) return null;
      final lat = loc['latitude'];
      final lng = loc['longitude'];
      if (lat is! num || lng is! num) return null;
      final la = lat.toDouble();
      final ln = lng.toDouble();
      if (!la.isFinite || !ln.isFinite) return null;
      return (la, ln);
    }();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: coverUrl != null ? 280 : 120,
          pinned: true,
          floating: false,
          backgroundColor: AppColors.primaryColorBlack,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: coverUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppColors.primaryColorBlack),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(color: AppColors.primaryColorBlack),
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColorBlack,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 36),
                            Text(
                              d.sellerPublicName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _TrustChip(
                                  icon: Icons.circle,
                                  label: d.providerStatus,
                                  color: _statusColor(d.providerStatus),
                                ),
                                _TrustChip(
                                  icon: Icons.star_rounded,
                                  label:
                                      '${d.providerRating.toStringAsFixed(1)} (${d.providerRatingCount})',
                                  color: Colors.amber.shade700,
                                ),
                                if (responseHint != null)
                                  _TrustChip(
                                    icon: Icons.schedule_outlined,
                                    label: 'Response $responseHint',
                                    color: AppColors.primaryColorBlack,
                                  ),
                                if (d.providerVerified)
                                  _TrustChip(
                                    icon: Icons.verified_outlined,
                                    label: 'Verified',
                                    color: Colors.green.shade700,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColorBlack.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.primaryColorBlack,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  d.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.description_outlined,
                  title: 'About',
                  child: Text(
                    d.description,
                    style: TextStyle(
                      height: 1.55,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (providerLoc != null) ...[
                  _SectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'Provider location',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerLoc,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                        if (providerLocLatLng != null) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () async {
                              final (la, ln) = providerLocLatLng;
                              final url =
                                  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$la,$ln')}';
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Open in Maps'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryColorBlack,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (thumbUrls.isNotEmpty) ...[
                  Text(
                    'Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ScrollConfiguration(
                      behavior: const _NoScrollbarBehavior(),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: thumbUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final url = thumbUrls[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 140,
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.grey.shade300),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Reviews',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 12),
                if (reviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'No reviews yet for this service',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...reviews.take(15).map((rev) => _ReviewCard(review: rev)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColorBlack.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryColorBlack.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.priceLabel,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!d.viewerIsOwner && d.priceType == 'RANGE') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _agreedAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Agreed amount (GMD)',
                      hintText: 'Enter amount within range',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryColorBlack,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
                if (!d.viewerIsOwner) ...[
                  const SizedBox(height: 24),
                  _SectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'Service location',
                    subtitle: 'Where should the service take place?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_mapsReadyChecked)
                          LinearProgressIndicator(
                            minHeight: 2,
                            color: AppColors.primaryColorBlack,
                            backgroundColor: Colors.grey.shade200,
                          )
                        else if (kMapsWebBaseUrl.trim().isNotEmpty &&
                            !_mapsBackendReady)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Location search is not available. Check MAPS_WEB_BASE_URL setup.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_pickedLocation != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.gambianGreen.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.gambianGreen.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  color: AppColors.gambianGreen,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SELECTED LOCATION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 0.9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _pickedLocation!.formattedAddress,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _clearPickedLocation,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade600,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                  ),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _locationSearchCtrl,
                            enabled: _mapsBackendReady,
                            decoration: InputDecoration(
                              prefixIcon: _searchBusy
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              hintText: 'Search for an address or place…',
                              labelText: 'Search location',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryColorBlack,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          if (_predictions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 240,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: _predictions.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                  ),
                                  itemBuilder: (context, i) {
                                    final p = _predictions[i];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        Icons.place_outlined,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                      title: Text(
                                        p.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      onTap: () => _pickPrediction(p),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryColorBlack,
                                side: BorderSide(
                                  color: AppColors.primaryColorBlack.withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: (!_mapsBackendReady || _locBusy)
                                  ? null
                                  : _useCurrentLocation,
                              icon: _locBusy
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryColorBlack,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                _locBusy ? 'Locating…' : 'Use current location',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _directionsNotesCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Extra directions (optional)',
                            hintText: 'Floor, gate colour, whom to ask for…',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColorBlack,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _jobNotesCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Job notes (optional)',
                            hintText: 'Timeline, tools you will provide…',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColorBlack,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (d.providerContact != null) ...[
                  const SizedBox(height: 20),
                  _SectionCard(
                    icon: Icons.person_outline,
                    title: 'Provider contact',
                    child: _ProviderContactCard(u: d.providerContact!),
                  ),
                ],
                const SizedBox(height: 24),
                if (d.viewerIsOwner)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is your listing — guests complete booking below with escrow.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primaryColorBlack,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: token == null ? null : _book,
                      icon: const Icon(Icons.book_online_outlined),
                      label: Text(
                        token == null ? 'Sign in to book' : 'Request booking',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 7 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryColorBlack),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] is num
        ? (review['rating'] as num).round()
        : 0;
    final comment = review['comment']?.toString().trim() ?? '';
    final createdAt = review['createdAt']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber.shade600,
                    size: 16,
                  );
                }),
              ),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                height: 1.4,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderContactCard extends StatelessWidget {
  final sm.MarketplaceUserContact u;

  const _ProviderContactCard({required this.u});

  @override
  Widget build(BuildContext context) {
    final name = u.displayName ?? u.fullName ?? 'Provider';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        if (u.phone != null && u.phone!.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse('tel:${u.phone}');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: Text(u.phone!),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColorBlack,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
        if (u.email != null && u.email!.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse('mailto:${u.email}');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            icon: const Icon(Icons.email_outlined, size: 18),
            label: Text(u.email!, style: const TextStyle(fontSize: 14)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColorBlack,
              padding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
