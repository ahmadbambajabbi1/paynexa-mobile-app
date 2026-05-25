class WalletSummary {
  WalletSummary({required this.userId, required this.currency, required this.balance});

  final String userId;
  final String currency;
  final String balance;

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      userId: json['userId'] as String? ?? '',
      currency: json['currency'] as String? ?? 'GMD',
      balance: (json['balance'] ?? '0').toString(),
    );
  }
}

class WalletLedgerEntry {
  WalletLedgerEntry({
    required this.id,
    required this.action,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String amount;
  final String balanceAfter;
  final DateTime createdAt;

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      amount: (json['amount'] ?? '0').toString(),
      balanceAfter: (json['balanceAfter'] ?? '0').toString(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PaymentMethodSummary {
  PaymentMethodSummary({
    required this.id,
    required this.provider,
    required this.type,
    required this.label,
    this.last4,
    this.brand,
    this.expMonth,
    this.expYear,
    this.msisdn,
  });

  final String id;
  final String provider;
  final String type;
  final String label;
  final String? last4;
  final String? brand;
  final int? expMonth;
  final int? expYear;
  final String? msisdn;

  factory PaymentMethodSummary.fromJson(Map<String, dynamic> json) {
    return PaymentMethodSummary(
      id: json['id'] as String? ?? '',
      provider: (json['provider'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      last4: json['last4'] as String?,
      brand: json['brand'] as String?,
      expMonth: json['expMonth'] is int ? json['expMonth'] as int : null,
      expYear: json['expYear'] is int ? json['expYear'] as int : null,
      msisdn: (json['modernpayMsisdn'] ?? json['msisdn']) as String?,
    );
  }
}

class WalletTransferSummary {
  WalletTransferSummary({
    required this.id,
    required this.kind,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String provider;
  final String amount;
  final String currency;
  final String status;
  final DateTime createdAt;

  factory WalletTransferSummary.fromJson(Map<String, dynamic> json) {
    return WalletTransferSummary(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      amount: (json['amount'] ?? '0').toString(),
      currency: (json['currency'] ?? 'GMD').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class WalletTransferStats {
  WalletTransferStats({
    required this.transferCount,
    required this.totalDeposited,
    required this.totalWithdrawn,
  });

  final int transferCount;
  final String totalDeposited;
  final String totalWithdrawn;

  factory WalletTransferStats.fromJson(Map<String, dynamic> json) {
    return WalletTransferStats(
      transferCount: (json['transferCount'] as num?)?.toInt() ?? 0,
      totalDeposited: (json['totalDeposited'] ?? '0').toString(),
      totalWithdrawn: (json['totalWithdrawn'] ?? '0').toString(),
    );
  }
}

