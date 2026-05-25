String? _optString(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

class ProfessionalApplication {
  ProfessionalApplication({
    required this.id,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String status;
  final String createdAt;

  factory ProfessionalApplication.fromJson(Map<String, dynamic> j) =>
      ProfessionalApplication(
        id: j['id'] as String,
        role: j['role'] as String,
        status: j['status'] as String,
        createdAt: _optString(j['createdAt']) ?? '',
      );

  bool get isPending =>
      status == 'SUBMITTED' || status == 'UNDER_REVIEW' || status == 'DRAFT';

  bool get isApproved => status.toUpperCase() == 'APPROVED';

  bool get isRejected => status == 'REJECTED';
}

class MeUser {
  MeUser({
    required this.id,
    this.phone,
    this.countryCode,
    this.email,
    this.emailVerifiedAt,
    this.displayName,
    this.fullName,
    this.profileCompletedAt,
    this.personalKycApprovedAt,
    this.personalKycStatus,
    this.personalKycVersion,
    this.personalKycRejectedReason,
    required this.createdAt,
    this.professionalApps = const [],
  });

  final String id;
  final String? phone;
  final String? countryCode;
  final String? email;
  final String? emailVerifiedAt;
  final String? displayName;
  final String? fullName;
  final String? profileCompletedAt;
  final String? personalKycApprovedAt;
  final String? personalKycStatus;
  final int? personalKycVersion;
  final String? personalKycRejectedReason;
  final String createdAt;
  final List<ProfessionalApplication> professionalApps;

  factory MeUser.fromJson(Map<String, dynamic> j) {
    final appsRaw = j['professionalApps'];
    final apps = <ProfessionalApplication>[];
    if (appsRaw is List) {
      for (final e in appsRaw) {
        if (e is Map<String, dynamic>) {
          apps.add(ProfessionalApplication.fromJson(e));
        }
      }
    }
    return MeUser(
      id: j['id'] as String,
      phone: j['phone'] as String?,
      countryCode: j['countryCode'] as String?,
      email: j['email'] as String?,
      emailVerifiedAt: _optString(j['emailVerifiedAt']),
      displayName: j['displayName'] as String?,
      fullName: j['fullName'] as String?,
      profileCompletedAt: _optString(j['profileCompletedAt']),
      personalKycApprovedAt: _optString(j['personalKycApprovedAt']),
      personalKycStatus: _optString(j['personalKycStatus']),
      personalKycVersion: j['personalKycVersion'] is int
          ? j['personalKycVersion'] as int
          : int.tryParse('${j['personalKycVersion'] ?? ''}'),
      personalKycRejectedReason: _optString(j['personalKycRejectedReason']),
      createdAt: _optString(j['createdAt']) ?? '',
      professionalApps: apps,
    );
  }

  ProfessionalApplication? applicationForRole(String roleUpper) {
    final r = roleUpper.toUpperCase();
    ProfessionalApplication? latest;
    DateTime? latestTime;
    for (final a in professionalApps) {
      if (a.role.toUpperCase() != r) continue;
      final t = DateTime.tryParse(a.createdAt)?.toUtc();
      if (latest == null) {
        latest = a;
        latestTime = t;
        continue;
      }
      if (t != null && latestTime != null && t.isAfter(latestTime)) {
        latest = a;
        latestTime = t;
      } else if (t != null && latestTime == null) {
        latest = a;
        latestTime = t;
      }
    }
    return latest;
  }

  /// Lawyer/agent KYC: can start a new application for this role.
  bool canApplyProfessionalKyc(String roleUpper) {
    final r = roleUpper.toUpperCase();
    if (r != 'LAWYER' && r != 'AGENT') return false;
    final hasOtherRole = professionalApps.any((a) => a.role.toUpperCase() != r);
    if (hasOtherRole) return false;
    final existing = applicationForRole(r);
    if (existing == null) return true;
    if (existing.isApproved) return false;
    if (existing.isPending) return false;
    return existing.isRejected;
  }

  /// Placeholder profile until [fetchMe] runs; matches server rule for `profileCompleted`.
  factory MeUser.loginBootstrap({
    required String userId,
    required bool profileCompleted,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    const placeholder = '2000-01-01T00:00:00.000Z';
    return MeUser(
      id: userId,
      createdAt: now,
      profileCompletedAt: profileCompleted ? placeholder : null,
      emailVerifiedAt: profileCompleted ? placeholder : null,
      professionalApps: const [],
    );
  }

  bool get profileReady =>
      profileCompletedAt != null && emailVerifiedAt != null;

  bool get personalKycApproved =>
      personalKycStatus == 'APPROVED' ||
      (personalKycStatus == null && personalKycApprovedAt != null);
}

class MeResponse {
  MeResponse({required this.user, required this.deviceId, required this.lastIp});

  final MeUser user;
  final String deviceId;
  final String lastIp;

  factory MeResponse.fromJson(Map<String, dynamic> j) => MeResponse(
        user: MeUser.fromJson(j['user'] as Map<String, dynamic>),
        deviceId: j['deviceId'] as String,
        lastIp: j['lastIp'] as String,
      );
}
