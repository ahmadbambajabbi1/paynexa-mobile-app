import 'dart:convert';

/// Mirrors [escrow_web/src/lib/parse-terms.ts] `termsPreview`.
String termsPreview(String terms) {
  try {
    final o = jsonDecode(terms);
    if (o is Map) {
      if (o['title'] is String) {
        final t = (o['title'] as String).trim();
        if (t.isNotEmpty) return t;
      }
      if (o['productTitle'] is String) {
        final t = (o['productTitle'] as String).trim();
        if (t.isNotEmpty) return t;
      }
    }
  } catch (_) {}
  final t = terms.trim();
  if (t.length > 80) return '${t.substring(0, 80)}…';
  return t.isEmpty ? 'Transaction' : t;
}

Map<String, String?>? parseTermsDeal(String terms) {
  try {
    final o = jsonDecode(terms);
    if (o is! Map) return null;
    return {
      'productTitle': o['productTitle'] as String?,
      'amount': o['amount'] as String?,
      'fundedBy': o['fundedBy'] as String?,
    };
  } catch (_) {
    return null;
  }
}
