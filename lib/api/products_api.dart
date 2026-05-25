import '../models/product_models.dart';
import 'api_client.dart';

Future<List<CatalogProductType>> fetchCatalogProductTypes(String token) async {
  final raw = await apiFetch(
    '/products/meta/product-types',
    method: 'GET',
    token: token,
  );
  final list = raw as List<dynamic>;
  return list
      .map((e) => CatalogProductType.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<ProductListResponse> listMyProducts(
  String token,
  int page,
  int pageSize, {
  String? sellerUserId,
}) async {
  final params = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
  if (sellerUserId != null && sellerUserId.isNotEmpty) {
    params['sellerUserId'] = sellerUserId;
  }
  final q = Uri(queryParameters: params).query;
  final raw =
      await apiFetch('/products?$q', method: 'GET', token: token)
          as Map<String, dynamic>;
  return ProductListResponse.fromJson(raw);
}

Future<ProductRow> fetchProduct(String token, String id) async {
  final raw =
      await apiFetch('/products/$id', method: 'GET', token: token)
          as Map<String, dynamic>;
  return ProductRow.fromJson(raw);
}

const Duration _kProductImageUploadTimeout = Duration(seconds: 120);

/// Description and attributes only (no image changes).
Future<ProductRow> updateProductDetails(
  String token,
  String productId, {
  String? name,
  String? description,
  Map<String, dynamic>? attributes,
}) async {
  final body = <String, dynamic>{};
  if (name != null) body['name'] = name;
  if (description != null) body['description'] = description;
  if (attributes != null) body['attributes'] = attributes;
  final raw =
      await apiFetch(
            '/products/$productId/details',
            method: 'PATCH',
            token: token,
            body: body,
          )
          as Map<String, dynamic>;
  return ProductRow.fromJson(raw);
}

/// Replaces cover/banner; old object is removed from storage on success.
Future<ProductRow> replaceProductBanner(
  String token,
  String productId, {
  required List<int> bannerBytes,
  required String bannerFilename,
  required String bannerContentType,
}) async {
  final raw = await apiMultipartPostJson(
    '/products/$productId/images/banner',
    token,
    fileBytes: bannerBytes,
    filename: bannerFilename,
    contentType: bannerContentType,
    sendTimeout: _kProductImageUploadTimeout,
    responseTimeout: _kProductImageUploadTimeout,
  );
  return ProductRow.fromJson(raw);
}

Future<ProductRow> appendProductGallery(
  String token,
  String productId,
  List<({List<int> bytes, String filename, String contentType})> gallery,
) async {
  final raw = await apiMultipartGalleryAppend(
    '/products/$productId/images/gallery',
    token,
    gallery: gallery,
  );
  return ProductRow.fromJson(raw);
}

/// Removes gallery images by R2 key (not the banner). At least one gallery image must remain.
Future<ProductRow> removeProductGalleryKeys(
  String token,
  String productId,
  List<String> keys,
) async {
  final raw =
      await apiFetch(
            '/products/$productId/images',
            method: 'DELETE',
            token: token,
            body: {'keys': keys},
          )
          as Map<String, dynamic>;
  return ProductRow.fromJson(raw);
}

/// Uploads images only on the server when the listing is saved (no orphan R2 objects if the user cancels).
Future<ProductRow> createProductComplete(
  String token, {
  required String productTypeId,
  required String name,
  required String description,
  required double price,
  required Map<String, dynamic> attributes,
  String visibility = 'PUBLISHED',
  required List<int> bannerBytes,
  required String bannerFilename,
  required String bannerContentType,
  required List<({List<int> bytes, String filename, String contentType})>
  gallery,
}) async {
  final raw = await apiMultipartProductComplete(
    '/products/complete',
    token,
    method: 'POST',
    metadata: {
      'productTypeId': productTypeId,
      'name': name,
      'description': description,
      'price': price,
      'attributes': attributes,
      'visibility': visibility,
    },
    bannerBytes: bannerBytes,
    bannerFilename: bannerFilename,
    bannerContentType: bannerContentType,
    gallery: gallery,
  );
  return ProductRow.fromJson(raw);
}

Future<ProductRow> publishProduct(String token, String productId) async {
  final raw =
      await apiFetch(
            '/products/$productId/publish',
            method: 'POST',
            token: token,
          )
          as Map<String, dynamic>;
  return ProductRow.fromJson(raw);
}

Future<ProductRow> updateProductComplete(
  String token,
  String productId, {
  String? name,
  required String description,
  required double price,
  required Map<String, dynamic> attributes,
  required List<String> keepProductImageKeys,
  required List<String> keepOtherImageKeys,
  List<int>? newBannerBytes,
  String? newBannerFilename,
  String? newBannerContentType,
  required List<({List<int> bytes, String filename, String contentType})>
  newGallery,
}) async {
  final raw = await apiMultipartProductComplete(
    '/products/$productId/complete',
    token,
    method: 'PATCH',
    metadata: {
      if (name != null) 'name': name,
      'description': description,
      'price': price,
      'attributes': attributes,
      'keepProductImageKeys': keepProductImageKeys,
      'keepOtherImageKeys': keepOtherImageKeys,
    },
    bannerBytes: newBannerBytes,
    bannerFilename: newBannerFilename,
    bannerContentType: newBannerContentType,
    gallery: newGallery,
  );
  return ProductRow.fromJson(raw);
}

Future<void> deleteProduct(String token, String id) async {
  await apiFetch('/products/$id', method: 'DELETE', token: token);
}

/// Optional: dynamic attribute fields that store an image key (uploads immediately — use sparingly).
Future<String> uploadProductImageFromBytes(
  String token,
  List<int> bytes,
  String contentType,
  String filename,
) async {
  final raw = await apiMultipartPostJson(
    '/products/uploads',
    token,
    fileBytes: bytes,
    filename: filename.isEmpty ? 'upload.jpg' : filename,
    contentType: contentType,
  );
  final key = raw['key'] as String?;
  if (key == null || key.isEmpty) {
    throw Exception('Upload response missing key');
  }
  return key;
}

/// Legacy JSON create (keys must already exist in R2).
Future<ProductRow> createProduct(
  String token, {
  required String productTypeId,
  required String name,
  required String description,
  required double price,
  required List<String> productImageUrls,
  required List<String> otherImageUrls,
  required Map<String, dynamic> attributes,
}) async {
  final raw =
      await apiFetch(
            '/products',
            method: 'POST',
            token: token,
            body: {
              'productTypeId': productTypeId,
              'name': name,
              'description': description,
              'price': price,
              'productImageUrls': productImageUrls,
              'otherImageUrls': otherImageUrls,
              'attributes': attributes,
            },
          )
          as Map<String, dynamic>;
  return ProductRow.fromJson(raw);
}
