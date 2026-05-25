/// Mirrors [escrow_web/src/lib/transaction-ui.ts].
const Map<String, List<String>> kStatusTransitions = {
  'AWAITING_ACCEPTANCE': ['CLOSED'],
  'AWAITING_FUNDING': ['CLOSED'],
  'FUNDED': ['IN_PROGRESS', 'DISPUTED'],
  'IN_PROGRESS': ['INSPECTION', 'DISPUTED'],
  'INSPECTION': ['COMPLETED', 'DISPUTED'],
  'COMPLETED': [],
  'DISPUTED': ['REFUNDED', 'COMPLETED'],
  'REFUNDED': [],
  'CLOSED': [],
};

bool canBuyerCloseTransaction(String role, {required String? buyerId, String? shareToken, required String status}) {
  if (role != 'buyer') return false;
  if (buyerId == null || buyerId.isEmpty) return false;
  if (shareToken != null && shareToken.isNotEmpty) return false;
  return {
    'AWAITING_ACCEPTANCE',
    'AWAITING_FUNDING',
  }.contains(status);
}

String formatTransactionType(String type) =>
    type.replaceAll('_', ' ').toLowerCase();

String formatStatus(String status) =>
    status.replaceAll('_', ' ').toLowerCase();

/// Visual progress width for list rows (API does not expose %).
double statusApproxProgress(String status) {
  const m = <String, double>{
    'AWAITING_ACCEPTANCE': 12,
    'AWAITING_FUNDING': 28,
    'FUNDED': 42,
    'IN_PROGRESS': 55,
    'INSPECTION': 72,
    'COMPLETED': 100,
    'DISPUTED': 50,
    'REFUNDED': 88,
    'CLOSED': 100,
  };
  return m[status] ?? 18;
}