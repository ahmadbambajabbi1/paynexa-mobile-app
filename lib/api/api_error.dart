import 'dart:async';
import 'dart:io';

class ApiError implements Exception {
  ApiError(this.status, this.body, [this.message]);

  final int status;
  final Object? body;
  final String? message;

  @override
  String toString() => message ?? 'Request failed ($status)';
}

String errorMessage(Object? err) {
  if (err is ApiError) {
    final s = err.status;
    if (s == 502 || s == 503 || s == 504) {
      final b = err.body;
      if (b is Map && b['message'] != null) {
        final m = b['message'];
        if (m is String && m.isNotEmpty && m.length < 220) {
          return '$m Check user-service, product-service, and transaction-service are running.';
        }
      }
      return 'Service is temporarily unavailable. Check the API gateway and backend services are running.';
    }
    if (s == 304) return 'Unexpected server response. Please try again.';
    if (s == 401) return 'Your session has expired. Please sign in again.';
    if (s == 403) return 'You are not allowed to perform this action.';
    final b = err.body;
    if (b is Map && b['message'] != null) {
      final m = b['message'];
      if (m is List && m.isNotEmpty) return m.join(', ');
      if (m is String && m.isNotEmpty && m.length < 180) return m;
    }
    return 'Request failed. Please try again.';
  }
  if (err is TimeoutException) {
    return 'Request timed out. Please try again.';
  }
  if (err is SocketException) {
    return 'Unable to reach the server. Check your network and try again.';
  }
  if (err is Exception) return 'Something went wrong. Please try again.';
  return 'Something went wrong';
}
