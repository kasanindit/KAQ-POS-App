import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class PasswordRecord {
  const PasswordRecord({
    required this.hash,
    required this.salt,
    required this.params,
  });

  final String hash;
  final String salt;
  final String params;
}

/// PBKDF2-HMAC-SHA256 + salt acak berbeda untuk setiap akun.
/// Password asli TIDAK pernah disimpan di SQLite.
class PasswordService {
  static const params = 'pbkdf2-sha256:210000:256';
  final _random = Random.secure();
  final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );

  Future<PasswordRecord> hashPassword(String password) async {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final key = await _algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final hashedBytes = await key.extractBytes();

    return PasswordRecord(
      hash: base64Encode(hashedBytes),
      salt: base64Encode(salt),
      params: params,
    );
  }

  Future<bool> verifyPassword({
    required String password,
    required String storedHash,
    required String storedSalt,
    required String storedParams,
  }) async {
    if (storedParams != params) return false;

    final salt = base64Decode(storedSalt);
    final expected = base64Decode(storedHash);
    final key = await _algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final actual = await key.extractBytes();

    // Bandingkan seluruh byte, bukan langsung String ==.
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }
}
