import '../models/product_models.dart';
import '../models/transaction_models.dart';
import 'parse_terms.dart';

String transactionRoomHeading(TransactionRoom room) {
  final p = room.product;
  if (p != null) return productDisplayName(p);
  final t = room.transaction.productTitle.trim();
  if (t.isNotEmpty) return t;
  return termsPreview(room.transaction.terms);
}

String timelineActorLabel(String actorId, TransactionRoom room, String selfId) {
  if (actorId == selfId) return 'You';
  final b = room.parties?.buyer;
  final s = room.parties?.seller;
  final bl = room.parties?.buyerLawyer;
  final ba = room.parties?.buyerAgent;
  final sl = room.parties?.sellerLawyer;
  final sa = room.parties?.sellerAgent;
  if (b?.id == actorId) {
    final n = b!.displayName?.trim();
    return n != null && n.isNotEmpty ? n : 'Buyer';
  }
  if (s?.id == actorId) {
    final n = s!.displayName?.trim();
    return n != null && n.isNotEmpty ? n : 'Seller';
  }
  if (bl?.id == actorId) {
    final n = bl!.displayName?.trim();
    return n != null && n.isNotEmpty ? n : 'Buyer’s lawyer';
  }
  if (ba?.id == actorId) {
    final n = ba!.displayName?.trim();
    return n != null && n.isNotEmpty ? n : 'Buyer’s agent';
  }
  if (sl?.id == actorId) {
    final n = sl!.displayName?.trim();
    return n != null && n.isNotEmpty ? n : 'Seller’s lawyer';
  }
  if (sa?.id == actorId) {
    final n = sa!.displayName?.trim();
    return n != null && n.isNotEmpty ? n : 'Seller’s agent';
  }
  return 'Participant';
}
