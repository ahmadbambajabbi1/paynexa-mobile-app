import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';

const Duration _kMapsTimeout = Duration(seconds: 22);
const String _kNomUserAgent = 'PayNexa-mobile/1.0 (escrow_app; support@paynexa)';

String _trimBase(String s) => s.replaceAll(RegExp(r'/+$'), '');

class MapsPlacePrediction {
  const MapsPlacePrediction({required this.placeId, required this.description});

  final String placeId;
  final String description;
}

class MapsPickedPlace {
  const MapsPickedPlace({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.placeId,
  });

  final String formattedAddress;
  final double lat;
  final double lng;
  final String? placeId;
}

Future<bool> isMapsSearchBackendReady() async {
  final raw = kMapsWebBaseUrl.trim();
  if (raw.isEmpty) return true;

  try {
    final uri = Uri.parse('${_trimBase(raw)}/api/maps/ready');
    final res = await http.get(uri).timeout(_kMapsTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    final j = jsonDecode(res.body);
    return j is Map && j['ready'] == true;
  } catch (_) {
    return false;
  }
}

Future<List<MapsPlacePrediction>> mapsAutocompletePlaces(String input) async {
  final q = input.trim();
  if (q.length < 2 || q.length > 256) return [];

  final base = kMapsWebBaseUrl.trim();
  if (base.isNotEmpty) {
    final uri = Uri.parse('${_trimBase(base)}/api/maps/autocomplete');
    try {
      final res = await http
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'input': q}),
          )
          .timeout(_kMapsTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final j = jsonDecode(res.body);
      final list = (j is Map ? j['predictions'] : null) as List<dynamic>?;
      if (list == null) return [];
      final mapped = list.whereType<Map<String, dynamic>>().map((row) {
        final pid = (row['placeId'] ?? '').toString();
        final desc = (row['description'] ?? '').toString();
        if (pid.isEmpty || desc.isEmpty) return null;
        return MapsPlacePrediction(placeId: pid, description: desc);
      });
      return mapped.whereType<MapsPlacePrediction>().toList();
    } catch (_) {
      return [];
    }
  }

  final uri =
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
      });
  try {
    final res = await http.get(
      uri,
      headers: {'User-Agent': _kNomUserAgent},
    ).timeout(_kMapsTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];

    final out = <MapsPlacePrediction>[];
    for (final row in decoded.whereType<Map<String, dynamic>>()) {
      final lat = row['lat'];
      final lon = row['lon'];
      final name = (row['display_name'] ?? '').toString().trim();
      final la = lat is String ? double.tryParse(lat) : (lat is num ? lat.toDouble() : null);
      final ln = lon is String ? double.tryParse(lon) : (lon is num ? lon.toDouble() : null);
      if (la == null ||
          ln == null ||
          !la.isFinite ||
          !ln.isFinite ||
          name.length < 3) {
        continue;
      }
      final placeId =
          'dev|$la|$ln|${Uri.encodeComponent(name)}';
      out.add(MapsPlacePrediction(placeId: placeId, description: name));
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<MapsPickedPlace?> mapsResolvePlace(MapsPlacePrediction pred) async {
  final base = kMapsWebBaseUrl.trim();
  if (base.isNotEmpty) {
    final uri = Uri.parse('${_trimBase(base)}/api/maps/place-details');
    try {
      final res = await http
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'placeId': pred.placeId}),
          )
          .timeout(_kMapsTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final j = jsonDecode(res.body);
      if (j is! Map<String, dynamic> || j['ok'] != true) return null;
      final formatted = (j['formattedAddress'] ?? '').toString().trim();
      final lat = j['lat'];
      final lng = j['lng'];
      final la = lat is num ? lat.toDouble() : double.tryParse('$lat');
      final ln = lng is num ? lng.toDouble() : double.tryParse('$lng');
      if (formatted.length < 8 || la == null || ln == null || !la.isFinite || !ln.isFinite) {
        return null;
      }
      final pid = j['placeId']?.toString();
      return MapsPickedPlace(
        formattedAddress: formatted,
        lat: la,
        lng: ln,
        placeId: pid != null && pid.isNotEmpty ? pid : pred.placeId,
      );
    } catch (_) {
      return null;
    }
  }

  final parts = pred.placeId.split('|');
  if (parts.length >= 4 && parts[0] == 'dev') {
    final la = double.tryParse(parts[1]);
    final ln = double.tryParse(parts[2]);
    final formatted = Uri.decodeComponent(parts.sublist(3).join('|')).trim();
    if (la != null &&
        ln != null &&
        la.isFinite &&
        ln.isFinite &&
        formatted.length >= 8) {
      return MapsPickedPlace(
        formattedAddress: formatted,
        lat: la,
        lng: ln,
        placeId: pred.placeId,
      );
    }
  }
  return null;
}

Future<MapsPickedPlace?> mapsReverseGeocode(double lat, double lng) async {
  if (!lat.isFinite || !lng.isFinite) return null;

  final base = kMapsWebBaseUrl.trim();
  if (base.isNotEmpty) {
    final uri = Uri.parse('${_trimBase(base)}/api/maps/reverse-geocode');
    try {
      final res = await http
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'lat': lat, 'lng': lng}),
          )
          .timeout(_kMapsTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final j = jsonDecode(res.body);
      if (j is! Map<String, dynamic> || j['ok'] != true) return null;
      final formatted = (j['formattedAddress'] ?? '').toString().trim();
      if (formatted.length < 8) return null;
      final pid = j['placeId']?.toString();
      return MapsPickedPlace(
        formattedAddress: formatted,
        lat: lat,
        lng: lng,
        placeId: pid != null && pid.isNotEmpty ? pid : null,
      );
    } catch (_) {
      return null;
    }
  }

  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'lat': lat.toString(),
    'lon': lng.toString(),
    'format': 'jsonv2',
  });
  try {
    final res = await http.get(
      uri,
      headers: {'User-Agent': _kNomUserAgent},
    ).timeout(_kMapsTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final j = jsonDecode(res.body);
    if (j is! Map<String, dynamic>) return null;
    final formatted = (j['display_name'] ?? '').toString().trim();
    if (formatted.length < 8) return null;
    final placeId =
        j['place_id'] != null ? '${j['place_id']}' : null;
    return MapsPickedPlace(
      formattedAddress: formatted,
      lat: lat,
      lng: lng,
      placeId: placeId,
    );
  } catch (_) {
    return null;
  }
}
