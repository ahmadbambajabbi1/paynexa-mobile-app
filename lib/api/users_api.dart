import '../models/me_user.dart';
import 'api_client.dart';

Future<void> phoneSendCode(String phone, String countryIso2) async {
  await apiFetch(
    '/users/auth/phone/send-code',
    method: 'POST',
    body: {'phone': phone, 'countryCode': countryIso2},
  );
}

Future<PhoneVerifySmsResult> phoneVerifySms(String phone, String code) async {
  final raw = await apiFetch(
    '/users/auth/phone/verify-sms',
    method: 'POST',
    body: {'phone': phone, 'code': code},
  ) as Map<String, dynamic>;
  return PhoneVerifySmsResult(
    nextStep: raw['nextStep'] as String,
    preAuthToken: raw['preAuthToken'] as String,
    hasAccount: raw['hasAccount'] as bool? ?? false,
  );
}

class PhoneVerifySmsResult {
  PhoneVerifySmsResult({
    required this.nextStep,
    required this.preAuthToken,
    required this.hasAccount,
  });

  final String nextStep;
  final String preAuthToken;
  final bool hasAccount;
}

Future<PhonePinSessionResult> phoneSetPin({
  required String preAuthToken,
  required String pin,
  required String deviceId,
  String? countryCode,
}) async {
  final raw = await apiFetch(
    '/users/auth/phone/set-pin',
    method: 'POST',
    body: {
      'preAuthToken': preAuthToken,
      'pin': pin,
      'deviceId': deviceId,
      'countryCode': countryCode,
    },
  ) as Map<String, dynamic>;
  return PhonePinSessionResult.fromJson(raw);
}

Future<PhonePinSessionResult> phoneVerifyPin({
  required String preAuthToken,
  required String pin,
  required String deviceId,
  String? countryCode,
}) async {
  final raw = await apiFetch(
    '/users/auth/phone/verify-pin',
    method: 'POST',
    body: {
      'preAuthToken': preAuthToken,
      'pin': pin,
      'deviceId': deviceId,
      'countryCode': countryCode,
    },
  ) as Map<String, dynamic>;
  return PhonePinSessionResult.fromJson(raw);
}

class PhonePinSessionResult {
  PhonePinSessionResult({
    required this.token,
    required this.deviceId,
    required this.userId,
    required this.profileCompleted,
  });

  final String token;
  final String deviceId;
  final String userId;
  final bool profileCompleted;

  factory PhonePinSessionResult.fromJson(Map<String, dynamic> j) =>
      PhonePinSessionResult(
        token: j['token'] as String,
        deviceId: j['deviceId'] as String,
        userId: j['userId'] as String,
        profileCompleted: j['profileCompleted'] as bool? ?? false,
      );
}

Future<MeResponse> fetchMe(String token) async {
  final raw = await apiFetch('/users/me', method: 'GET', token: token)
      as Map<String, dynamic>;
  return MeResponse.fromJson(raw);
}

Future<void> registerFcmToken(
  String token, {
  required String fcmToken,
  String? platform,
}) async {
  await apiFetch(
    '/users/devices/fcm-token',
    method: 'POST',
    token: token,
    body: {
      'fcmToken': fcmToken,
      if (platform != null) 'platform': platform,
    },
  );
}

Future<CompleteProfileResponse> completeProfile(
  String token, {
  required String displayName,
  required String fullName,
}) async {
  final raw = await apiFetch(
    '/users/profile/complete',
    method: 'POST',
    token: token,
    body: {
      'displayName': displayName,
      'fullName': fullName,
    },
  ) as Map<String, dynamic>;
  return CompleteProfileResponse(
    ok: raw['ok'] as bool? ?? false,
    profileComplete: raw['profileComplete'] as bool?,
    profileCompletedAt: raw['profileCompletedAt'] as String?,
  );
}

class CompleteProfileResponse {
  CompleteProfileResponse({
    required this.ok,
    this.profileComplete,
    this.profileCompletedAt,
  });

  final bool ok;
  final bool? profileComplete;
  final String? profileCompletedAt;
}

Future<void> verifyProfileEmail(String token, String code) async {
  await apiFetch(
    '/users/profile/verify-email',
    method: 'POST',
    token: token,
    body: {'code': code},
  );
}

Future<void> resendProfileEmailVerification(String token) async {
  await apiFetch(
    '/users/profile/resend-email-verification',
    method: 'POST',
    token: token,
  );
}

Future<LookupUserResult> lookupUserByPhone(String token, String phone) async {
  final q = Uri(queryParameters: {'phone': phone}).query;
  final raw = await apiFetch('/users/lookup?$q', method: 'GET', token: token)
      as Map<String, dynamic>;
  return LookupUserResult(
    userId: raw['userId'] as String,
    phone: raw['phone'] as String,
  );
}

Future<LookupUserResult> lookupUserByQuery(String token, String queryValue) async {
  final q = Uri(queryParameters: {'query': queryValue}).query;
  final raw = await apiFetch('/users/search?$q', method: 'GET', token: token)
      as Map<String, dynamic>;
  return LookupUserResult(
    userId: raw['id'] as String,
    phone: raw['phone'] as String? ?? '',
    email: raw['email'] as String?,
    displayName: raw['displayName'] as String?,
  );
}

class LookupUserResult {
  LookupUserResult({
    required this.userId,
    required this.phone,
    this.email,
    this.displayName,
  });

  final String userId;
  final String phone;
  final String? email;
  final String? displayName;
}

Future<ProfessionalApplyResult> applyProfessionalRole(
  String token, {
  required String role,
  Map<String, dynamic>? details,
}) async {
  final raw = await apiFetch(
    '/users/professional-roles/apply',
    method: 'POST',
    token: token,
    body: {
      'role': role,
      if (details != null && details.isNotEmpty) 'details': details,
    },
  ) as Map<String, dynamic>;
  return ProfessionalApplyResult(
    applicationId: raw['applicationId'] as String,
    role: raw['role'] as String,
    status: raw['status'] as String,
  );
}

class ProfessionalApplyResult {
  ProfessionalApplyResult({
    required this.applicationId,
    required this.role,
    required this.status,
  });

  final String applicationId;
  final String role;
  final String status;
}

/// Allowed by user-service R2 KYC upload (see `ALLOWED_KYC_MIME` in Nest).
bool isAllowedKycUploadFilename(String filename) {
  final n = filename.toLowerCase();
  return n.endsWith('.pdf') ||
      n.endsWith('.png') ||
      n.endsWith('.webp') ||
      n.endsWith('.gif') ||
      n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.jfif');
}

String _kycContentTypeForFilename(String filename) {
  final n = filename.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.jfif')) return 'image/jpeg';
  return 'application/octet-stream';
}

Future<String> uploadKycFile(
  String token,
  List<int> bytes,
  String filename,
) async {
  final safe = filename.isEmpty ? 'document.pdf' : filename;
  if (!isAllowedKycUploadFilename(safe)) {
    throw Exception(
      'Unsupported file type. Use PDF, JPEG, PNG, WebP, or GIF.',
    );
  }
  final raw = await apiMultipartPostJson(
    '/users/kyc/uploads',
    token,
    fileBytes: bytes,
    filename: safe,
    contentType: _kycContentTypeForFilename(safe),
    sendTimeout: const Duration(seconds: 90),
    responseTimeout: const Duration(seconds: 90),
  );
  final key = raw['key'] as String?;
  if (key == null || key.isEmpty) {
    throw Exception('Upload response missing key');
  }
  return key;
}

Future<void> submitKycDocument(
  String token, {
  required String kind,
  String? professionalApplicationId,
  required String fileKey,
  required String uploader,
}) async {
  await apiFetch(
    '/users/kyc',
    method: 'POST',
    token: token,
    body: {
      'kind': kind,
      'professionalApplicationId': professionalApplicationId,
      'fileKey': fileKey,
      'fileUrl': fileKey,
      'uploader': uploader,
    },
  );
}

Future<PersonalKycStatus> fetchPersonalKycStatus(String token, String userId) async {
  final q = Uri(queryParameters: {'userId': userId}).query;
  final raw = await apiFetch('/users/kyc/personal-status?$q', method: 'GET', token: token)
      as Map<String, dynamic>;
  return PersonalKycStatus(
    approved: raw['approved'] as bool? ?? false,
    approvedAt: raw['approvedAt'] as String?,
  );
}

class PersonalKycStatus {
  PersonalKycStatus({required this.approved, this.approvedAt});

  final bool approved;
  final String? approvedAt;
}

class DeliveryAddress {
  DeliveryAddress({
    required this.id,
    this.label,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.stateRegion,
    required this.postalCode,
    required this.country,
    this.deliveryInstructions,
    required this.isDefault,
  });

  final String id;
  final String? label;
  final String fullName;
  final String phone;
  final String email;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String stateRegion;
  final String postalCode;
  final String country;
  final String? deliveryInstructions;
  final bool isDefault;

  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
    id: j['id'] as String,
    label: j['label'] as String?,
    fullName: j['fullName'] as String,
    phone: j['phone'] as String,
    email: j['email'] as String,
    addressLine1: j['addressLine1'] as String,
    addressLine2: j['addressLine2'] as String?,
    city: j['city'] as String,
    stateRegion: j['stateRegion'] as String,
    postalCode: j['postalCode'] as String,
    country: j['country'] as String,
    deliveryInstructions: j['deliveryInstructions'] as String?,
    isDefault: j['isDefault'] as bool? ?? false,
  );
}

Future<List<DeliveryAddress>> listDeliveryAddresses(String token) async {
  final raw = await apiFetch('/users/me/delivery-addresses', method: 'GET', token: token)
      as Map<String, dynamic>;
  final items = raw['items'];
  if (items is! List) return [];
  return items
      .whereType<Map<String, dynamic>>()
      .map(DeliveryAddress.fromJson)
      .toList();
}

Future<DeliveryAddress> createDeliveryAddress(
  String token, {
  String? label,
  required String fullName,
  required String phone,
  required String email,
  required String addressLine1,
  String? addressLine2,
  required String city,
  required String stateRegion,
  required String postalCode,
  required String country,
  String? deliveryInstructions,
  bool isDefault = false,
}) async {
  final raw = await apiFetch(
    '/users/me/delivery-addresses',
    method: 'POST',
    token: token,
    body: {
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'addressLine1': addressLine1,
      if (addressLine2 != null && addressLine2.trim().isNotEmpty) 'addressLine2': addressLine2.trim(),
      'city': city,
      'stateRegion': stateRegion,
      'postalCode': postalCode,
      'country': country,
      if (deliveryInstructions != null && deliveryInstructions.trim().isNotEmpty)
        'deliveryInstructions': deliveryInstructions.trim(),
      'isDefault': isDefault,
    },
  ) as Map<String, dynamic>;
  return DeliveryAddress.fromJson(raw);
}
