import 'api_client.dart';

class ProfessionalFeeItem {
  ProfessionalFeeItem({
    required this.productTypeId,
    required this.code,
    required this.name,
    this.feeAmount,
  });

  final String productTypeId;
  final String code;
  final String name;
  final String? feeAmount;

  factory ProfessionalFeeItem.fromJson(Map<String, dynamic> j) =>
      ProfessionalFeeItem(
        productTypeId: j['productTypeId'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        feeAmount: j['feeAmount'] as String?,
      );
}

class ProfessionalFeesResponse {
  ProfessionalFeesResponse({required this.role, required this.items});

  final String role;
  final List<ProfessionalFeeItem> items;

  factory ProfessionalFeesResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['items'];
    final items = <ProfessionalFeeItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          items.add(ProfessionalFeeItem.fromJson(e));
        }
      }
    }
    return ProfessionalFeesResponse(
      role: j['role'] as String,
      items: items,
    );
  }
}

Future<ProfessionalFeesResponse> fetchProfessionalFees(String token) async {
  final r = await apiFetch('/products/me/professional-fees', token: token);
  if (r is! Map<String, dynamic>) {
    throw StateError('invalid response');
  }
  return ProfessionalFeesResponse.fromJson(r);
}

Future<Map<String, dynamic>> putProfessionalFee(
  String token,
  String productTypeId,
  String feeAmount,
) async {
  final path =
      '/products/me/professional-fees/${Uri.encodeComponent(productTypeId)}';
  final r = await apiFetch(
    path,
    method: 'PUT',
    token: token,
    body: <String, dynamic>{'feeAmount': feeAmount},
  );
  if (r is Map<String, dynamic>) return r;
  return <String, dynamic>{};
}
