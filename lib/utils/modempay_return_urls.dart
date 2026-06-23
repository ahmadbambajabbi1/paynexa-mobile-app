import '../config/constants.dart';

/// HTTPS return URLs for Modem Pay (custom schemes are not supported in checkout).
/// The web bridge pages redirect back into the app via [kDeepLinkScheme] when `source=app`.
({String returnUrl, String cancelUrl}) buildModernPayReturnUrls({
  required String context,
  String? id,
}) {
  final base = kWebBaseUrl.replaceAll(RegExp(r'/$'), '');
  final params = <String, String>{
    'source': 'app',
    'context': context,
  };
  if (id != null && id.isNotEmpty) {
    params['id'] = id;
  }
  final qs = _queryString(params);
  return (
    returnUrl: '$base/wallet/deposit/success?$qs',
    cancelUrl: '$base/wallet/deposit/cancel?$qs',
  );
}

String _queryString(Map<String, String> params) {
  return params.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
}
