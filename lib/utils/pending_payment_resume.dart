/// Remembers an in-flight wallet top-up so the app can resume escrow payment after Modem Pay.
class PendingPaymentResume {
  PendingPaymentResume._();

  static String? context;
  static String? ref;
  static String? transactionId;
  static double? amount;

  static void save({
    required String context,
    required String transactionId,
    String? ref,
    double? amount,
  }) {
    PendingPaymentResume.context = context;
    PendingPaymentResume.ref = ref;
    PendingPaymentResume.transactionId = transactionId;
    PendingPaymentResume.amount = amount;
  }

  static void clear() {
    context = null;
    ref = null;
    transactionId = null;
    amount = null;
  }

  static bool get hasPending => transactionId != null && transactionId!.isNotEmpty;
}
