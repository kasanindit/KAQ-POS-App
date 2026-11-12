import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pos_app/data/database/app_database.dart';
import 'package:pos_app/data/model/auth.dart';
import 'package:pos_app/data/model/password_service.dart';
import 'package:pos_app/utils/helper/auth_validators.dart';

class AuthRepository {
  final AppDatabase _db;
  final PasswordService _passwords;
  final FlutterSecureStorage _storage;
  final Random _random = Random.secure();

  static const _sessionKey = 'session_token';

  AuthRepository({
    required AppDatabase appDatabase,
    required PasswordService passwordService,
    required FlutterSecureStorage secureStorage,
  }) : _db = appDatabase,
       _passwords = passwordService,
       _storage = secureStorage;

  String _newId() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> init() async {
    await _db.database;
  }

  Future<void> register({
    required String displayName,
    required String username,
    required String password,
  }) async {
    final nameError = AuthValidators.requiredName(displayName, 'Nama kasir');
    final usernameError = AuthValidators.username(username);
    final passwordError = AuthValidators.password(password);
    if (nameError != null) throw FormatException(nameError);
    if (usernameError != null) throw FormatException(usernameError);
    if (passwordError != null) throw FormatException(passwordError);

    final normalizedUsername = username.trim().toLowerCase();
    final passwordRecord = await _passwords.hashPassword(password);
    final db = await _db.database;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'users',
        columns: ['id'],
        where: 'username = ?',
        whereArgs: [normalizedUsername],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError('Username sudah digunakan. Pilih username lain.');
      }

      await txn.insert('users', {
        'id': _newId(),
        'username': normalizedUsername,
        'display_name': displayName.trim(),
        'password_hash': passwordRecord.hash,
        'salt': passwordRecord.salt,
        'kdf_params': passwordRecord.params,
        'is_active': 1,
      });
    });
  }

  /// null berarti kredensial salah / akun tidak aktif.

  Future<AuthUser?> login(String username, String password) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;

    final verified = await _passwords.verifyPassword(
      password: password,
      storedHash: row['password_hash'] as String,
      storedSalt: row['salt'] as String,
      storedParams: row['kdf_params'] as String,
    );

    if (!verified) return null;

    final user = AuthUser.fromMap(row);

    final sessionId = _newId();
    final now = _now();

    await db.transaction((txn) async {
      // Nonaktifkan session sebelumnya
      await txn.update(
        'local_sessions',
        {'is_active': 0},
        where: 'is_active = ?',
        whereArgs: [1],
      );

      // Buat session baru
      await txn.insert('local_sessions', {
        'id': sessionId,
        'user_id': user.id,
        'issued_at': now,
        'last_seen_at': now,
        'is_active': 1,
      });
    });

    try {
      await _storage.write(key: _sessionKey, value: sessionId);
    } catch (_) {
      // Jika gagal, nonaktifkan session baru
      await db.update(
        'local_sessions',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      rethrow;
    }

    return user;
  }

  Future<AuthUser?> restoreSession() async {
    final sessionId = await _storage.read(key: _sessionKey);
    if (sessionId == null) return null;

    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT u.id, u.username, u.display_name
      FROM local_sessions s
      JOIN users u ON u.id = s.user_id
      WHERE s.id = ? AND s.is_active = 1 AND u.is_active = 1
      LIMIT 1
    ''',
      [sessionId],
    );

    if (rows.isEmpty) {
      await _storage.delete(key: _sessionKey);
      return null;
    }

    await db.update(
      'local_sessions',
      {'last_seen_at': _now()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return AuthUser.fromMap(rows.first);
  }

  Future<void> logout() async {
    final sessionId = await _storage.read(key: _sessionKey);
    if (sessionId != null) {
      final db = await _db.database;
      await db.update(
        'local_sessions',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    }
    await _storage.delete(key: _sessionKey);
  }
}
