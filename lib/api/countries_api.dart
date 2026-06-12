import 'api_client.dart';

class OperatingCountry {
  const OperatingCountry({
    required this.iso2,
    required this.name,
    required this.dialCode,
    required this.currencyCode,
    required this.currencyName,
    required this.currencySymbol,
  });

  final String iso2;
  final String name;
  final String dialCode;
  final String currencyCode;
  final String currencyName;
  final String currencySymbol;

  factory OperatingCountry.fromJson(Map<String, dynamic> json) {
    return OperatingCountry(
      iso2: (json['iso2'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      dialCode: (json['dialCode'] ?? '').toString(),
      currencyCode: (json['currencyCode'] ?? '').toString(),
      currencyName: (json['currencyName'] ?? '').toString(),
      currencySymbol: (json['currencySymbol'] ?? '').toString(),
    );
  }
}

Future<List<OperatingCountry>> listOperatingCountries() async {
  final raw = await apiFetch('/users/countries/operating') as Map<String, dynamic>;
  final rows = raw['countries'];
  if (rows is! List) return const [];
  return rows
      .whereType<Map>()
      .map((row) => OperatingCountry.fromJson(Map<String, dynamic>.from(row)))
      .where((country) => country.iso2.isNotEmpty && country.dialCode.isNotEmpty)
      .toList(growable: false);
}
