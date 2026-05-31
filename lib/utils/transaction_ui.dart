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

bool canBuyerCloseTransaction(
  String role, {
  required String? buyerId,
  String? shareToken,
  required String status,
}) {
  if (role != 'buyer') return false;
  if (buyerId == null || buyerId.isEmpty) return false;
  if (shareToken != null && shareToken.isNotEmpty) return false;
  return {'AWAITING_ACCEPTANCE', 'AWAITING_FUNDING'}.contains(status);
}

String formatTransactionType(String type) =>
    type.replaceAll('_', ' ').toLowerCase();

String formatStatus(String status) => status.replaceAll('_', ' ').toLowerCase();

String formatTimelineAction(String action, String detail) {
  if (action == 'state.changed') {
    final state = detail.startsWith('state=') ? detail.substring(6) : '';
    return switch (state) {
      'IN_PROGRESS' => 'Delivery started',
      'INSPECTION' => 'Sent to buyer for inspection',
      'COMPLETED' => 'Transaction completed',
      'DISPUTED' => 'Dispute opened',
      'REFUNDED' => 'Payment refunded',
      'CLOSED' => 'Transaction closed',
      'AWAITING_FUNDING' => 'Waiting for payment',
      'AWAITING_ACCEPTANCE' => 'Waiting for acceptance',
      _ => 'Transaction updated',
    };
  }

  return switch (action) {
    'public.created' => 'Payment link created',
    'escrow.created' => 'Transaction created',
    'transaction.accepted' => 'Transaction accepted',
    'public.claimed' => 'Buyer joined the transaction',
    'payment.funded' => 'Payment secured in escrow',
    'agreement.versioned' => 'Agreement updated',
    'dispute.created' => 'Dispute opened',
    'document.added' => 'Document added',
    _ => action.replaceAll('.', ' ').replaceAll('_', ' '),
  };
}

String formatTimelineDetail(String action, String detail) {
  if (detail.isEmpty || detail.startsWith('state=')) return '';
  if (action == 'payment.funded') return 'Escrow was funded from the wallet.';
  if (action == 'agreement.versioned' && detail.startsWith('v')) {
    return 'Version ${detail.substring(1)}';
  }
  return detail;
}

String transitionActionLabel(String nextState) {
  return switch (nextState) {
    'IN_PROGRESS' => 'Start delivery',
    'INSPECTION' => 'Send to buyer',
    'COMPLETED' => 'Confirm and release money',
    'DISPUTED' => 'Open dispute',
    'REFUNDED' => 'Refund buyer',
    'CLOSED' => 'Close transaction',
    _ => formatStatus(nextState),
  };
}

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
