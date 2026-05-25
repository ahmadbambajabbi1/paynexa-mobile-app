import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_error.dart';
import '../api/users_api.dart';
import '../config/constants.dart';
import '../models/me_user.dart';

/// Session + profile state aligned with [escrow_web/src/lib/auth/auth-context.tsx].
class AuthController extends ChangeNotifier {
  AuthController() : _secure = const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  String? _token;
  MeUser? _user;
  bool _loading = true;

  String? get token => _token;
  MeUser? get user => _user;
  bool get loading => _loading;

  /// Same rule as [escrow_web/src/lib/auth/profile.ts] `isProfileComplete`.
  bool get profileReady => _user?.profileReady ?? false;

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    try {
      _token = await _secure.read(key: kStorageAccessToken);
      if (_token != null && _token!.isNotEmpty) {
        final me = await fetchMe(_token!);
        _user = me.user;
      } else {
        _user = null;
      }
    } catch (_) {
      await _secure.delete(key: kStorageAccessToken);
      _token = null;
      _user = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// After phone PIN, the server already returns a valid session; waiting on
  /// [fetchMe] here used to block the UI on a second `/users/me` round-trip
  /// (gateway auth + proxy). Pass [pinBootstrap] so we hydrate in the background.
  Future<void> applySessionToken(
    String accessToken, {
    PhonePinSessionResult? pinBootstrap,
  }) async {
    await _secure.write(key: kStorageAccessToken, value: accessToken);
    _token = accessToken;
    notifyListeners();
    try {
      if (pinBootstrap != null) {
        _user = MeUser.loginBootstrap(
          userId: pinBootstrap.userId,
          profileCompleted: pinBootstrap.profileCompleted,
        );
        notifyListeners();
        unawaited(_hydrateUserAfterPinLogin());
        return;
      }
      final me = await fetchMe(accessToken);
      _user = me.user;
    } catch (_) {
      await _secure.delete(key: kStorageAccessToken);
      _token = null;
      _user = null;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _hydrateUserAfterPinLogin() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    try {
      final me = await fetchMe(t);
      _user = me.user;
      notifyListeners();
    } catch (e, st) {
      if (e is ApiError && (e.status == 401 || e.status == 403)) {
        await logout();
        return;
      }
      debugPrint('hydrate user after PIN failed: $e\n$st');
    }
  }

  Future<void> logout() async {
    await _secure.delete(key: kStorageAccessToken);
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    final me = await fetchMe(t);
    _user = me.user;
    notifyListeners();
  }

  Future<CompleteProfileResponse> submitProfileDetails({
    required String displayName,
    required String fullName,
    required String email,
  }) async {
    final t = _token;
    if (t == null || t.isEmpty) throw StateError('Not signed in');
    final res = await completeProfile(
      t,
      displayName: displayName,
      fullName: fullName,
      email: email,
    );
    await refreshUser();
    return res;
  }

  Future<void> verifyEmailCode(String code) async {
    final t = _token;
    if (t == null || t.isEmpty) throw StateError('Not signed in');
    await verifyProfileEmail(t, code);
    await refreshUser();
  }

  Future<void> resendEmailVerification() async {
    final t = _token;
    if (t == null || t.isEmpty) throw StateError('Not signed in');
    await resendProfileEmailVerification(t);
  }
}
