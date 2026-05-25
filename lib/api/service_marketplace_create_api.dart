import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/constants.dart';
import '../data/device_id_service.dart';
import 'api_error.dart';

MediaType _multipartMediaType(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return MediaType('application', 'octet-stream');
  }
  try {
    return MediaType.parse(raw.trim());
  } catch (_) {
    return MediaType('application', 'octet-stream');
  }
}

Future<Map<String, dynamic>> apiMultipartServiceListingComplete(
  String token, {
  required Map<String, dynamic> metadata,
  required List<int> coverBytes,
  required String coverFilename,
  required String coverContentType,
  required List<({List<int> bytes, String filename, String contentType})> gallery,
}) async {
  if (coverBytes.isEmpty) throw StateError('coverBytes empty');
  if (gallery.isEmpty) throw StateError('gallery empty');

  final base = kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final uri = Uri.parse('$base/service-marketplace/listings/complete');
  final deviceId = await DeviceIdService.instance.getOrCreate();
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';
  req.headers['X-Device-Id'] = deviceId;
  req.headers['Cache-Control'] = 'no-cache';
  req.headers['Pragma'] = 'no-cache';

  req.fields['metadata'] = jsonEncode(metadata);
  req.files.add(
    http.MultipartFile.fromBytes(
      'cover',
      coverBytes,
      filename: coverFilename.isEmpty ? 'cover.jpg' : coverFilename,
      contentType: _multipartMediaType(coverContentType),
    ),
  );
  for (final g in gallery) {
    req.files.add(
      http.MultipartFile.fromBytes(
        'gallery',
        g.bytes,
        filename: g.filename.isEmpty ? 'photo.jpg' : g.filename,
        contentType: _multipartMediaType(g.contentType),
      ),
    );
  }

  final streamed = await req.send().timeout(const Duration(seconds: 120));
  final response =
      await http.Response.fromStream(streamed).timeout(const Duration(seconds: 120));

  final text = response.body;
  Object? parsed;
  if (text.isNotEmpty) {
    try {
      parsed = jsonDecode(text) as Object?;
    } catch (_) {
      parsed = {'message': text};
    }
  } else {
    parsed = <String, dynamic>{};
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    String? msg;
    if (parsed is Map && parsed['message'] != null) {
      final o = parsed['message'];
      if (o is String) msg = o;
      if (o is List) msg = o.join(', ');
    }
    throw ApiError(response.statusCode, parsed, msg);
  }

  return parsed as Map<String, dynamic>;
}

