import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../config/constants.dart';

/// Persists a stable device id (aligned with escrow_web [getOrCreateDeviceId]).
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();
  String? _memory;

  Future<String> getOrCreate() async {
    final mem = _memory;
    if (mem != null && mem.isNotEmpty) return mem;
    final existing = await _storage.read(key: kStorageDeviceId);
    if (existing != null && existing.isNotEmpty) {
      _memory = existing;
      return existing;
    }
    final id = _uuid.v4();
    await _storage.write(key: kStorageDeviceId, value: id);
    _memory = id;
    return id;
  }
}
