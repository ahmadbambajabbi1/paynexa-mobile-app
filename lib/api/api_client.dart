import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/constants.dart';
import '../data/device_id_service.dart';
import 'api_error.dart';

const Duration _kApiRequestTimeout = Duration(seconds: 45);
const Duration _kApiMultipartProductTimeout = Duration(seconds: 120);

/// Multipart upload (e.g. product or KYC files through the API gateway).
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

Future<Map<String, dynamic>> apiMultipartPostJson(
  String path,
  String token, {
  required List<int> fileBytes,
  required String filename,
  String? contentType,
  Duration? sendTimeout,
  Duration? responseTimeout,
}) async {
  final sendT = sendTimeout ?? _kApiRequestTimeout;
  final responseT = responseTimeout ?? _kApiRequestTimeout;
  final base = kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final uri = Uri.parse('$base$path');
  final deviceId = await DeviceIdService.instance.getOrCreate();
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';
  req.headers['X-Device-Id'] = deviceId;
  req.headers['Cache-Control'] = 'no-cache';
  req.headers['Pragma'] = 'no-cache';
  req.files.add(
    http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
      contentType: _multipartMediaType(contentType),
    ),
  );
  final streamed = await req.send().timeout(sendT);
  final response = await http.Response.fromStream(streamed).timeout(responseT);
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

/// Product create/update with banner + gallery: files only hit the server on submit.
Future<Map<String, dynamic>> apiMultipartProductComplete(
  String path,
  String token, {
  required String method,
  required Map<String, dynamic> metadata,
  List<int>? bannerBytes,
  String? bannerFilename,
  String? bannerContentType,
  required List<({List<int> bytes, String filename, String contentType})> gallery,
}) async {
  final base = kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final uri = Uri.parse('$base$path');
  final deviceId = await DeviceIdService.instance.getOrCreate();
  final req = http.MultipartRequest(method.toUpperCase(), uri);
  req.headers['Authorization'] = 'Bearer $token';
  req.headers['X-Device-Id'] = deviceId;
  req.headers['Cache-Control'] = 'no-cache';
  req.headers['Pragma'] = 'no-cache';
  req.fields['metadata'] = jsonEncode(metadata);
  final bb = bannerBytes;
  if (bb != null && bb.isNotEmpty) {
    final fn = bannerFilename ?? 'banner.jpg';
    req.files.add(
      http.MultipartFile.fromBytes(
        'banner',
        bb,
        filename: fn.isEmpty ? 'banner.jpg' : fn,
        contentType: _multipartMediaType(bannerContentType ?? 'image/jpeg'),
      ),
    );
  }
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

  final streamed = await req.send().timeout(_kApiMultipartProductTimeout);
  final response =
      await http.Response.fromStream(streamed).timeout(_kApiMultipartProductTimeout);
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

/// Append gallery images (`gallery` field repeated; same timeout as full product submit).
Future<Map<String, dynamic>> apiMultipartGalleryAppend(
  String path,
  String token, {
  required List<({List<int> bytes, String filename, String contentType})> gallery,
}) async {
  if (gallery.isEmpty) {
    throw StateError('apiMultipartGalleryAppend: empty gallery');
  }
  final base = kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final uri = Uri.parse('$base$path');
  final deviceId = await DeviceIdService.instance.getOrCreate();
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';
  req.headers['X-Device-Id'] = deviceId;
  req.headers['Cache-Control'] = 'no-cache';
  req.headers['Pragma'] = 'no-cache';
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
  final streamed = await req.send().timeout(_kApiMultipartProductTimeout);
  final response =
      await http.Response.fromStream(streamed).timeout(_kApiMultipartProductTimeout);
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

/// Mirrors [escrow_web/src/lib/api/client.ts]: gateway base URL, `X-Device-Id`, `Authorization`.
Future<dynamic> apiFetch(
  String path, {
  String method = 'GET',
  String? token,
  Object? body,
}) async {
  final base = kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final uri = Uri.parse('$base$path');
  final headers = <String, String>{
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };
  final deviceId = await DeviceIdService.instance.getOrCreate();
  headers['X-Device-Id'] = deviceId;
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  final hasBody = body != null;
  if (hasBody) {
    headers['Content-Type'] = 'application/json';
  }
  final encoded = hasBody ? jsonEncode(body) : null;

  late final http.Response response;
  final m = method.toUpperCase();
  if (m == 'GET') {
    response = await http.get(uri, headers: headers).timeout(_kApiRequestTimeout);
  } else if (m == 'POST') {
    response = await http
        .post(uri, headers: headers, body: encoded)
        .timeout(_kApiRequestTimeout);
  } else if (m == 'PATCH') {
    response = await http
        .patch(uri, headers: headers, body: encoded)
        .timeout(_kApiRequestTimeout);
  } else {
    final req = http.Request(m, uri);
    req.headers.addAll(headers);
    if (encoded != null) req.body = encoded;
    response = await http.Response.fromStream(
      await req.send().timeout(_kApiRequestTimeout),
    ).timeout(_kApiRequestTimeout);
  }

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

  return parsed;
}
