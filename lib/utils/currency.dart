const Map<String, String> _currencySymbols = {
  'GMD': 'D',
  'XOF': 'CFA',
  'GHS': 'GH₵',
  'NGN': '₦',
  'SLE': 'Le',
  'GNF': 'FG',
  'LRD': 'L\$',
  'MRU': 'UM',
  'CVE': '\$',
  'KES': 'KSh',
  'UGX': 'USh',
  'TZS': 'TSh',
  'ZAR': 'R',
  'USD': '\$',
  'GBP': '£',
  'CAD': '\$',
  'AED': 'د.إ',
};

String currencySymbol(String? currency) {
  final code = currency?.trim().toUpperCase();
  if (code == null || code.isEmpty) return '';
  return _currencySymbols[code] ?? code;
}

String moneyText(Object? amount, String? currency) {
  final raw = amount?.toString() ?? '0';
  final parsed = double.tryParse(raw);
  final value = parsed == null ? raw : parsed.toStringAsFixed(2);
  final symbol = currencySymbol(currency);
  return symbol.isEmpty ? value : '$symbol$value';
}
