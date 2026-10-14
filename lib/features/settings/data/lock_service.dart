import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores an optional app-level PIN (for locked notes) in secure storage.
/// The PIN itself is never persisted in plain text.
class LockService {
  LockService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kPinHash = 'aalumai_pin_hash';

  Future<bool> get hasPin async =>
      (await _storage.read(key: _kPinHash)) != null;

  Future<void> setPin(String pin) =>
      _storage.write(key: _kPinHash, value: _hash(pin));

  Future<void> clearPin() => _storage.delete(key: _kPinHash);

  Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: _kPinHash);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}

final lockServiceProvider = Provider<LockService>((ref) => LockService());
