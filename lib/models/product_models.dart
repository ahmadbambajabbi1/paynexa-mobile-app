class ProductTypeFieldDef {
  ProductTypeFieldDef({
    required this.name,
    this.label,
    required this.valueType,
    required this.required,
  });

  final String name;
  final String? label;
  final String valueType;
  final bool required;

  factory ProductTypeFieldDef.fromJson(Map<String, dynamic> j) =>
      ProductTypeFieldDef(
        name: j['name'] as String,
        label: j['label'] as String?,
        valueType: j['valueType'] as String,
        required: j['required'] == false ? false : true,
      );
}

class CatalogProductType {
  CatalogProductType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.fieldDefinitions,
    required this.lawyerPricingEnabled,
    required this.agentPricingEnabled,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final List<ProductTypeFieldDef> fieldDefinitions;
  final bool lawyerPricingEnabled;
  final bool agentPricingEnabled;

  factory CatalogProductType.fromJson(Map<String, dynamic> j) =>
      CatalogProductType(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        fieldDefinitions: _parseFieldDefs(j['fieldDefinitions']),
        lawyerPricingEnabled: j['lawyerPricingEnabled'] as bool? ?? false,
        agentPricingEnabled: j['agentPricingEnabled'] as bool? ?? false,
      );

  static List<ProductTypeFieldDef> _parseFieldDefs(dynamic raw) {
    if (raw is! List) return [];
    final out = <ProductTypeFieldDef>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      if (m['name'] is! String || m['valueType'] is! String) continue;
      out.add(ProductTypeFieldDef.fromJson(m));
    }
    return out;
  }
}

/// Short label for lists / selects when [name] is empty (legacy listings).
String productDisplayName(ProductRow p) {
  final n = p.name.trim();
  if (n.isNotEmpty) return n;
  final d = p.description.trim();
  if (d.length <= 120) return d;
  return '${d.substring(0, 120)}…';
}

class ProductRow {
  ProductRow({
    required this.id,
    required this.sellerUserId,
    required this.productTypeId,
    required this.name,
    required this.description,
    required this.price,
    required this.visibility,
    required this.productImages,
    required this.otherImages,
    required this.productImageKeys,
    required this.otherImageKeys,
    required this.attributes,
    required this.createdAt,
    required this.updatedAt,
    required this.productType,
  });

  final String id;
  final String sellerUserId;
  final String productTypeId;

  /// Short listing title (lists, escrow product pickers).
  final String name;
  final String description;
  final String price;
  final String visibility;

  /// Signed GET URLs for display.
  final List<String> productImages;
  final List<String> otherImages;

  /// R2 keys (for edits / server round-trip).
  final List<String> productImageKeys;
  final List<String> otherImageKeys;
  final Map<String, dynamic> attributes;
  final String createdAt;
  final String updatedAt;
  final CatalogProductType productType;

  factory ProductRow.fromJson(Map<String, dynamic> j) => ProductRow(
    id: j['id'] as String,
    sellerUserId: j['sellerUserId'] as String,
    productTypeId: j['productTypeId'] as String,
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    price: (j['price'] ?? '').toString(),
    visibility: (j['visibility'] as String?) ?? 'PUBLISHED',
    productImages: _strList(j['productImages']),
    otherImages: _strList(j['otherImages']),
    productImageKeys: _strList(j['productImageKeys']),
    otherImageKeys: _strList(j['otherImageKeys']),
    attributes: _attrMap(j['attributes']),
    createdAt: j['createdAt'] as String,
    updatedAt: j['updatedAt'] as String,
    productType: CatalogProductType.fromJson(
      j['productType'] as Map<String, dynamic>,
    ),
  );

  static List<String> _strList(dynamic v) {
    if (v is! List) return [];
    return v.whereType<String>().toList();
  }

  static Map<String, dynamic> _attrMap(dynamic v) {
    if (v is! Map) return {};
    return Map<String, dynamic>.from(v);
  }
}

class ProductListResponse {
  ProductListResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<ProductRow> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  factory ProductListResponse.fromJson(Map<String, dynamic> j) =>
      ProductListResponse(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => ProductRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 12,
        total: (j['total'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      );
}
