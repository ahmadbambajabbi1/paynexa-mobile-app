import '../models/wallet_models.dart';
import 'api_client.dart';

Future<Map<String, dynamic>> getEscrowConfig(String token) async {
  final raw = await apiFetch('/escrow/config', method: 'GET', token: token) as Map<String, dynamic>;
  return raw;
}

Future<WalletSummary> getWallet(String token) async {
  final raw = await apiFetch('/escrow/wallet', method: 'GET', token: token) as Map<String, dynamic>;
  return WalletSummary.fromJson(raw);
}

Future<WalletTransferStats> getWalletTransferStats(String token) async {
  final raw =
      await apiFetch('/escrow/wallet/stats', method: 'GET', token: token) as Map<String, dynamic>;
  return WalletTransferStats.fromJson(raw);
}

Future<List<WalletTransferSummary>> getWalletTransfers(
  String token, {
  int limit = 20,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/transfers?limit=$limit',
    method: 'GET',
    token: token,
  ) as Map<String, dynamic>;
  final list = (raw['transfers'] as List?) ?? const [];
  return list
      .whereType<Map>()
      .map((e) => WalletTransferSummary.fromJson(e.cast<String, dynamic>()))
      .toList();
}

Future<List<WalletLedgerEntry>> getWalletLedger(String token, {int limit = 50}) async {
  final raw = await apiFetch(
    '/escrow/wallet/ledger?limit=$limit',
    method: 'GET',
    token: token,
  ) as Map<String, dynamic>;
  final list = (raw['entries'] as List?) ?? const [];
  return list
      .whereType<Map>()
      .map((e) => WalletLedgerEntry.fromJson(e.cast<String, dynamic>()))
      .toList();
}

Future<List<PaymentMethodSummary>> listPaymentMethods(String token) async {
  final raw = await apiFetch('/escrow/payment-methods', method: 'GET', token: token) as Map<String, dynamic>;
  final list = (raw['methods'] as List?) ?? const [];
  return list
      .whereType<Map>()
      .map((e) => PaymentMethodSummary.fromJson(e.cast<String, dynamic>()))
      .toList();
}

Future<Map<String, dynamic>> createStripeSetupIntent(String token) async {
  final raw = await apiFetch(
    '/escrow/payment-methods/stripe/setup-intent',
    method: 'POST',
    token: token,
  ) as Map<String, dynamic>;
  return raw;
}

Future<PaymentMethodSummary> completeStripeSetupIntent(
  String token, {
  required String setupIntentId,
  String? label,
}) async {
  final raw = await apiFetch(
    '/escrow/payment-methods/stripe/complete-setup',
    method: 'POST',
    token: token,
    body: {'setupIntentId': setupIntentId, 'label': label},
  ) as Map<String, dynamic>;
  return PaymentMethodSummary.fromJson(raw);
}

Future<PaymentMethodSummary> addModernPayMobileMoneyMethod(
  String token, {
  required String msisdn,
  String? label,
}) async {
  final raw = await apiFetch(
    '/escrow/payment-methods/modernpay',
    method: 'POST',
    token: token,
    body: {'msisdn': msisdn, 'label': label},
  ) as Map<String, dynamic>;
  return PaymentMethodSummary.fromJson(raw);
}

Future<Map<String, dynamic>> createStripeDepositIntent(
  String token, {
  required double amount,
  String? paymentMethodId,
  String? clientRequestId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/deposits/stripe',
    method: 'POST',
    token: token,
    body: {
      'amount': amount,
      'paymentMethodId': paymentMethodId,
      'clientRequestId': clientRequestId,
    },
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> confirmSavedCardStripeDeposit(
  String token, {
  required double amount,
  required String paymentMethodId,
  String? clientRequestId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/deposits/stripe/confirm-saved-card',
    method: 'POST',
    token: token,
    body: {
      'amount': amount,
      'paymentMethodId': paymentMethodId,
      'clientRequestId': clientRequestId,
    },
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> createModernPayDepositIntent(
  String token, {
  required double amount,
  String? clientRequestId,
  String? returnUrl,
  String? cancelUrl,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/deposits/modernpay',
    method: 'POST',
    token: token,
    body: {
      'amount': amount,
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
      if (returnUrl != null) 'returnUrl': returnUrl,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
    },
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> confirmModernPayDeposit(
  String token, {
  required String transferId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/deposits/modernpay/confirm',
    method: 'POST',
    token: token,
    body: {'transferId': transferId},
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> syncStripeDeposit(
  String token, {
  required String transferId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/deposits/stripe/sync',
    method: 'POST',
    token: token,
    body: {'transferId': transferId},
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> payTransactionFromWallet(
  String token, {
  required String transactionId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/transactions/${Uri.encodeComponent(transactionId)}/pay',
    method: 'POST',
    token: token,
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> getTransactionPaymentQuote(
  String token, {
  required String transactionId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/transactions/${Uri.encodeComponent(transactionId)}/payment-quote',
    method: 'GET',
    token: token,
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> payMarketplaceServiceBooking(
  String token, {
  required String bookingId,
  required String providerUserId,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/marketplace-service-bookings/pay',
    method: 'POST',
    token: token,
    body: {
      'bookingId': bookingId,
      'providerUserId': providerUserId,
    },
  ) as Map<String, dynamic>;
  return raw;
}

Future<Map<String, dynamic>> requestPayout(
  String token, {
  required double amount,
  required String provider,
  String? clientRequestId,
  Map<String, dynamic>? providerPayload,
}) async {
  final raw = await apiFetch(
    '/escrow/wallet/payouts',
    method: 'POST',
    token: token,
    body: {
      'amount': amount,
      'provider': provider,
      'clientRequestId': clientRequestId,
      'providerPayload': providerPayload,
    },
  ) as Map<String, dynamic>;
  return raw;
}

