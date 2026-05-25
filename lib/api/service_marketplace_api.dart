import 'api_client.dart';

bool marketplaceLooksLikeOpaqueUserId(String value, Object? userId) {
  final v = value.trim();
  if (v.isEmpty) return true;
  final uid = userId?.toString().trim() ?? '';
  if (uid.isNotEmpty && v == uid) return true;
  if (RegExp(r'^c[a-z0-9]{24,}$', caseSensitive: false).hasMatch(v))
    return true;
  if (RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(v)) return true;
  return false;
}

class ServiceCategory {
  ServiceCategory({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  static ServiceCategory fromJson(Map<String, dynamic> j) {
    return ServiceCategory(
      id: j['id'] as String,
      code: j['code'] as String,
      name: j['name'] as String,
    );
  }
}

class ServiceListingRow {
  ServiceListingRow({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryName,
    required this.providerName,
    required this.providerUserId,
    required this.status,
    required this.ratingAvg,
    required this.ratingCount,
    required this.avgResponseTimeSec,
    required this.providerLocationLine,
    required this.distanceKm,
    required this.priceLabel,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final String description;
  final String categoryName;
  final String providerName;
  final String providerUserId;
  final String status;
  final double ratingAvg;
  final int ratingCount;
  final int avgResponseTimeSec;
  final String? providerLocationLine;
  final double? distanceKm;
  final String priceLabel;
  final String? coverImageUrl;

  static ServiceListingRow fromSearchItem(Map<String, dynamic> item) {
    final listing = item['listing'] as Map<String, dynamic>;
    final provider = listing['provider'] as Map<String, dynamic>;
    final category = listing['category'] as Map<String, dynamic>;

    final priceType = (listing['priceType'] as String?) ?? 'FIXED';
    final priceAmount = listing['priceAmount']?.toString();
    final priceMin = listing['priceMin']?.toString();
    final priceMax = listing['priceMax']?.toString();
    final priceLabel = priceType == 'FIXED'
        ? 'D${priceAmount ?? ''}'
        : 'D${priceMin ?? ''}–D${priceMax ?? ''}';

    final d = item['distanceKm'];
    final distanceKm = d is num ? d.toDouble() : null;

    final cov = listing['coverImage'];
    String? coverUrl;
    if (cov is String && cov.startsWith('http')) {
      coverUrl = cov;
    }

    String? providerLocationLine;
    final loc = provider['location'];
    if (loc is Map) {
      final addressText = (loc['addressText'] as String?)?.trim();
      final region = (loc['region'] as String?)?.trim();
      final parts = <String>[];
      if (addressText != null && addressText.isNotEmpty) parts.add(addressText);
      if (region != null && region.isNotEmpty) parts.add(region);
      final line = parts.join(' · ').trim();
      if (line.length >= 2) providerLocationLine = line;
    }

    final uid = provider['userId'];
    final rawName = (provider['displayName'] as String?)?.trim();
    final safeName =
        rawName != null &&
            rawName.isNotEmpty &&
            !marketplaceLooksLikeOpaqueUserId(rawName, uid)
        ? rawName
        : 'Provider';

    return ServiceListingRow(
      id: listing['id'] as String,
      title: (listing['title'] as String?) ?? '',
      description: (listing['description'] as String?) ?? '',
      categoryName: (category['name'] as String?) ?? 'Service',
      providerName: safeName,
      providerUserId: (provider['userId'] as String?) ?? '',
      status: (provider['status'] as String?) ?? 'OFFLINE',
      ratingAvg: (provider['ratingAvg'] is num)
          ? (provider['ratingAvg'] as num).toDouble()
          : 0.0,
      ratingCount: (provider['ratingCount'] is num)
          ? (provider['ratingCount'] as num).round()
          : 0,
      avgResponseTimeSec: (provider['avgResponseTimeSec'] is num)
          ? (provider['avgResponseTimeSec'] as num).round()
          : 0,
      providerLocationLine: providerLocationLine,
      distanceKm: distanceKm,
      priceLabel: priceLabel,
      coverImageUrl: coverUrl,
    );
  }
}

class MarketplaceUserContact {
  MarketplaceUserContact({
    required this.id,
    this.displayName,
    this.fullName,
    this.email,
    this.phone,
    this.countryCode,
  });

  final String id;
  final String? displayName;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? countryCode;

  static MarketplaceUserContact? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    return MarketplaceUserContact(
      id: (j['id'] as String?) ?? '',
      displayName: j['displayName'] as String?,
      fullName: j['fullName'] as String?,
      email: j['email'] as String?,
      phone: j['phone'] as String?,
      countryCode: j['countryCode'] as String?,
    );
  }
}

class ServiceListingDetailResult {
  ServiceListingDetailResult({
    required this.raw,
    required this.viewerIsOwner,
    this.providerContact,
  });

  final Map<String, dynamic> raw;
  final bool viewerIsOwner;
  final MarketplaceUserContact? providerContact;

  String get id => raw['id'] as String;
  String get title => (raw['title'] as String?) ?? '';
  String get description => (raw['description'] as String?) ?? '';
  String get priceType => (raw['priceType'] as String?) ?? 'FIXED';
  String get priceLabel {
    final pt = priceType;
    if (pt == 'FIXED') {
      return 'D${raw['priceAmount'] ?? ''}';
    }
    return 'D${raw['priceMin'] ?? ''}–D${raw['priceMax'] ?? ''}';
  }

  String? get coverUrl {
    final c = raw['coverImage'];
    if (c is String && c.startsWith('http')) return c;
    return null;
  }

  List<String> get galleryUrls {
    final imgs = raw['serviceImages'];
    if (imgs is! List) return [];
    return imgs.whereType<String>().where((s) => s.startsWith('http')).toList();
  }

  Map<String, dynamic> get provider =>
      (raw['provider'] as Map<String, dynamic>?) ?? {};

  String get providerDisplay {
    final uid = provider['userId'];
    final dn = (provider['displayName'] as String?)?.trim();
    if (dn != null &&
        dn.isNotEmpty &&
        !marketplaceLooksLikeOpaqueUserId(dn, uid)) {
      return dn;
    }
    return 'Provider';
  }

  /// Matches web: merged `provider.displayName` first, then signed-in contact fields.
  String get sellerPublicName {
    final uid = provider['userId'];
    final api = (provider['displayName'] as String?)?.trim();
    if (api != null &&
        api.isNotEmpty &&
        !marketplaceLooksLikeOpaqueUserId(api, uid)) {
      return api;
    }
    final dn = providerContact?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final fn = providerContact?.fullName?.trim();
    if (fn != null && fn.isNotEmpty) return fn;
    return providerDisplay;
  }

  List<Map<String, dynamic>> get reviewsRows {
    final r = raw['reviews'];
    if (r is! List) return const [];
    return r.whereType<Map<String, dynamic>>().toList();
  }

  String get providerStatus => (provider['status'] as String?) ?? 'OFFLINE';

  double get providerRating => provider['ratingAvg'] is num
      ? (provider['ratingAvg'] as num).toDouble()
      : 0.0;

  int get providerRatingCount => provider['ratingCount'] is num
      ? (provider['ratingCount'] as num).round()
      : 0;

  int get providerAvgResponseTimeSec => provider['avgResponseTimeSec'] is num
      ? (provider['avgResponseTimeSec'] as num).round()
      : 0;

  bool get providerVerified =>
      '${provider['verificationStatus'] ?? ''}'.toLowerCase() == 'verified';

  String? get providerLocationLine {
    final loc = provider['location'];
    if (loc is! Map) return null;
    final addressText = (loc['addressText'] as String?)?.trim();
    final region = (loc['region'] as String?)?.trim();
    final parts = <String>[];
    if (addressText != null && addressText.isNotEmpty) parts.add(addressText);
    if (region != null && region.isNotEmpty) parts.add(region);
    final line = parts.join(' · ').trim();
    return line.length >= 2 ? line : null;
  }
}

DateTime? _lastRenderingPingAt;

Future<void> maybePingRenderingLocation({
  required String token,
  required double latitude,
  required double longitude,
  String? locationLabel,
}) async {
  final now = DateTime.now();
  if (_lastRenderingPingAt != null &&
      now.difference(_lastRenderingPingAt!) < const Duration(seconds: 125)) {
    return;
  }
  _lastRenderingPingAt = now;
  try {
    await apiFetch(
      '/service-marketplace/providers/me/rendering-location',
      method: 'PATCH',
      token: token,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        if (locationLabel != null && locationLabel.trim().isNotEmpty)
          'locationLabel': locationLabel.trim(),
      },
    );
  } catch (_) {
    _lastRenderingPingAt = null;
  }
}

Future<List<ServiceCategory>> listServiceCategories() async {
  final res = await apiFetch('/service-marketplace/categories');
  final map = res as Map<String, dynamic>;
  final items = (map['categories'] as List<dynamic>? ?? const []);
  return items
      .whereType<Map<String, dynamic>>()
      .map(ServiceCategory.fromJson)
      .toList();
}

Future<List<ServiceListingRow>> searchServiceListings({
  double? latitude,
  double? longitude,
  String? categoryId,
  bool onlineOnly = false,
}) async {
  final qp = <String, String>{
    'onlineOnly': onlineOnly ? 'true' : 'false',
    'page': '1',
    'pageSize': '50',
  };
  if (latitude != null && longitude != null) {
    qp['latitude'] = latitude.toString();
    qp['longitude'] = longitude.toString();
  }
  if (categoryId != null && categoryId.trim().isNotEmpty) {
    qp['categoryId'] = categoryId.trim();
  }
  final uri = Uri(
    path: '/service-marketplace/listings/search',
    queryParameters: qp,
  );
  final res = await apiFetch('${uri.path}?${uri.query}');
  final map = res as Map<String, dynamic>;
  final items = (map['items'] as List<dynamic>? ?? const []);
  return items
      .whereType<Map<String, dynamic>>()
      .map(ServiceListingRow.fromSearchItem)
      .toList();
}

Future<ServiceListingDetailResult> getServiceListing({
  required String id,
  String? token,
}) async {
  final path = '/service-marketplace/listings/${Uri.encodeComponent(id)}';
  final res = await apiFetch(path, token: token) as Map<String, dynamic>;
  final listing = res['listing'] as Map<String, dynamic>;
  final owner = res['viewerIsOwner'] == true;
  final contactJson = res['providerContact'] ?? res['providerTransparency'];
  return ServiceListingDetailResult(
    raw: listing,
    viewerIsOwner: owner,
    providerContact: MarketplaceUserContact.fromJson(contactJson),
  );
}

Future<Map<String, dynamic>> publishServiceListing({
  required String token,
  required String listingId,
}) async {
  return (await apiFetch(
        '/service-marketplace/listings/${Uri.encodeComponent(listingId)}/publish',
        method: 'POST',
        token: token,
      ))
      as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> listMyServiceListings({
  required String token,
}) async {
  final res =
      await apiFetch('/service-marketplace/listings/me', token: token)
          as Map<String, dynamic>;
  final items = (res['listings'] as List<dynamic>? ?? const []);
  return items.whereType<Map<String, dynamic>>().toList();
}

Future<Map<String, dynamic>> createBooking({
  required String token,
  required String listingId,
  required DateTime scheduledAt,
  double? agreedAmount,
  String? notes,
  double? serviceLatitude,
  double? serviceLongitude,
  String? serviceAddressText,
  String? serviceLocationLabel,
  String? serviceGooglePlaceId,
}) async {
  return (await apiFetch(
        '/service-marketplace/listings/${Uri.encodeComponent(listingId)}/bookings',
        method: 'POST',
        token: token,
        body: {
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          if (agreedAmount != null) 'agreedAmount': agreedAmount,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (serviceLatitude != null) 'serviceLatitude': serviceLatitude,
          if (serviceLongitude != null) 'serviceLongitude': serviceLongitude,
          if (serviceAddressText != null &&
              serviceAddressText.trim().isNotEmpty)
            'serviceAddressText': serviceAddressText.trim(),
          if (serviceLocationLabel != null &&
              serviceLocationLabel.trim().isNotEmpty)
            'serviceLocationLabel': serviceLocationLabel.trim(),
          if (serviceGooglePlaceId != null &&
              serviceGooglePlaceId.trim().isNotEmpty)
            'serviceGooglePlaceId': serviceGooglePlaceId.trim(),
        },
      ))
      as Map<String, dynamic>;
}

Future<Map<String, dynamic>> updateBookingState({
  required String token,
  required String bookingId,
  required String action,
  String? notes,
}) async {
  return (await apiFetch(
        '/service-marketplace/bookings/${Uri.encodeComponent(bookingId)}/state',
        method: 'PATCH',
        token: token,
        body: {
          'action': action,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      ))
      as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> listMyServiceBookings({
  required String token,
}) async {
  final res =
      await apiFetch('/service-marketplace/bookings/me', token: token)
          as Map<String, dynamic>;
  final items = res['bookings'] as List<dynamic>? ?? const [];
  return items.whereType<Map<String, dynamic>>().toList();
}

Future<List<Map<String, dynamic>>> listProviderServiceBookings({
  required String token,
}) async {
  final res =
      await apiFetch('/service-marketplace/bookings/provider', token: token)
          as Map<String, dynamic>;
  final items = res['bookings'] as List<dynamic>? ?? const [];
  return items.whereType<Map<String, dynamic>>().toList();
}

Future<void> submitBookingReview({
  required String token,
  required String bookingId,
  required int rating,
  String? comment,
}) async {
  await apiFetch(
    '/service-marketplace/bookings/${Uri.encodeComponent(bookingId)}/review',
    method: 'POST',
    token: token,
    body: {
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    },
  );
}
