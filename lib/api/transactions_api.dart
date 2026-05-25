import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/transaction_models.dart';
import 'api_client.dart';
import '../config/constants.dart';
import '../data/device_id_service.dart';

Future<TransactionListResponse> listTransactionsForParty(
  String token,
  String userId,
) async {
  final q = Uri(queryParameters: {
    'buyerId': userId,
    'sellerId': userId,
  }).query;
  final raw = await apiFetch('/transactions/by-party?$q', method: 'GET', token: token)
      as Map<String, dynamic>;
  return TransactionListResponse.fromJson(raw);
}

Future<TransactionRoom> getTransactionRoom(String token, String id) async {
  final raw = await apiFetch(
    '/transactions/${Uri.encodeComponent(id)}',
    method: 'GET',
    token: token,
  ) as Map<String, dynamic>;
  return TransactionRoom.fromJson(raw);
}

Future<CreateTransactionResult> createTransaction(
  String token, {
  required String createdByUserId,
  required String counterpartyId,
  required String role,
  required String productId,
  required String fundedBy,
  String? type,
}) async {
  final raw = await apiFetch(
    '/transactions',
    method: 'POST',
    token: token,
    body: {
      'createdByUserId': createdByUserId,
      'counterpartyId': counterpartyId,
      'role': role,
      'productId': productId,
      'fundedBy': fundedBy,
      if (type != null) 'type': type,
    },
  ) as Map<String, dynamic>;
  return CreateTransactionResult(
    transactionId: raw['transactionId'] as String,
    status: raw['status'] as String? ?? '',
    paymentLinkPath: raw['paymentLinkPath'] as String?,
  );
}

Future<CreateTransactionResult> createEscrowTransaction(
  String token, {
  required String createdByUserId,
  required String counterpartyId,
  required String productId,
  String? type,
}) async {
  final raw = await apiFetch(
    '/transactions/escrow',
    method: 'POST',
    token: token,
    body: {
      'createdByUserId': createdByUserId,
      'counterpartyId': counterpartyId,
      'productId': productId,
      if (type != null) 'type': type,
    },
  ) as Map<String, dynamic>;
  return CreateTransactionResult(
    transactionId: raw['transactionId'] as String,
    status: raw['status'] as String? ?? '',
    paymentLinkPath: raw['paymentLinkPath'] as String?,
  );
}

Future<CreateTransactionResult> createPublicTransaction(
  String token, {
  required String createdByUserId,
  required String itemTitle,
  String? itemDescription,
  required int quantity,
  required double unitPrice,
  bool? deliveryNeeded,
  String? sellerNote,
  String? type,
}) async {
  final raw = await apiFetch(
    '/transactions/public',
    method: 'POST',
    token: token,
    body: {
      'createdByUserId': createdByUserId,
      'itemTitle': itemTitle,
      if (itemDescription != null) 'itemDescription': itemDescription,
      'quantity': quantity,
      'unitPrice': unitPrice,
      if (deliveryNeeded != null) 'deliveryNeeded': deliveryNeeded,
      if (sellerNote != null) 'sellerNote': sellerNote,
      if (type != null) 'type': type,
    },
  ) as Map<String, dynamic>;
  return CreateTransactionResult(
    transactionId: raw['transactionId'] as String,
    status: raw['status'] as String? ?? '',
    paymentLinkPath: raw['paymentLinkPath'] as String?,
  );
}

Future<TransactionNotificationResponse> listTransactionNotifications(
  String token,
  String userId,
) async {
  final q = Uri(queryParameters: {'userId': userId}).query;
  final raw = await apiFetch(
    '/transactions/notifications?$q',
    method: 'GET',
    token: token,
  ) as Map<String, dynamic>;
  return TransactionNotificationResponse.fromJson(raw);
}

Future<void> markTransactionNotificationRead(String token, String id) async {
  await apiFetch(
    '/transactions/notifications/${Uri.encodeComponent(id)}/read',
    method: 'PATCH',
    token: token,
  );
}

Stream<Map<String, dynamic>> transactionNotificationEvents(
  String token,
  String userId,
) async* {
  final base = kApiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final uri = Uri.parse(
    '$base/transactions/notifications/stream?userId=${Uri.encodeQueryComponent(userId)}',
  );
  final deviceId = await DeviceIdService.instance.getOrCreate();
  final client = HttpClient();
  final req = await client.getUrl(uri);
  req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  req.headers.set('X-Device-Id', deviceId);
  final res = await req.close();
  await for (final line in res.transform(utf8.decoder).transform(const LineSplitter())) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) continue;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        yield decoded;
      }
    } catch (_) {}
  }
}

class CreateTransactionResult {
  CreateTransactionResult({
    required this.transactionId,
    required this.status,
    this.paymentLinkPath,
  });

  final String transactionId;
  final String status;
  final String? paymentLinkPath;
}

Future<void> acceptTransaction(
  String token,
  String id,
  String actorId,
) async {
  await apiFetch(
    '/transactions/${Uri.encodeComponent(id)}/accept',
    method: 'PATCH',
    token: token,
    body: {'actorId': actorId},
  );
}

Future<void> updateTransactionState(
  String token,
  String id,
  String actorId,
  String newState,
) async {
  await apiFetch(
    '/transactions/${Uri.encodeComponent(id)}/state',
    method: 'PATCH',
    token: token,
    body: {'actorId': actorId, 'newState': newState},
  );
}

Future<ParticipantSearchResult> searchTransactionParticipants(
  String token,
  String transactionId,
  String role,
  String query, {
  required String partySide,
}) async {
  final q = Uri(queryParameters: {
    'role': role,
    'query': query,
    'partySide': partySide,
  }).query;
  final raw = await apiFetch(
    '/transactions/${Uri.encodeComponent(transactionId)}/participants/search?$q',
    method: 'GET',
    token: token,
  ) as Map<String, dynamic>;
  return ParticipantSearchResult.fromJson(raw);
}

Future<void> inviteTransactionParticipant(
  String token,
  String transactionId, {
  required String actorId,
  required String participantUserId,
  required String role,
  required String partySide,
  String? message,
}) async {
  await apiFetch(
    '/transactions/${Uri.encodeComponent(transactionId)}/invite-participant',
    method: 'PATCH',
    token: token,
    body: {
      'actorId': actorId,
      'participantUserId': participantUserId,
      'role': role,
      'partySide': partySide,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    },
  );
}

Future<void> acceptTransactionParticipantInvite(
  String token,
  String transactionId, {
  required String actorId,
  required String role,
  required String partySide,
}) async {
  await apiFetch(
    '/transactions/${Uri.encodeComponent(transactionId)}/participant-accept',
    method: 'PATCH',
    token: token,
    body: {
      'actorId': actorId,
      'role': role,
      'partySide': partySide,
    },
  );
}

Future<void> claimPublicTransaction(
  String token,
  String transactionId,
  String buyerId,
) async {
  await apiFetch(
    '/transactions/public/${Uri.encodeComponent(transactionId)}/claim',
    method: 'POST',
    token: token,
    body: {
      'buyerId': buyerId,
    },
  );
}
