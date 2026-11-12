import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Future<Database>? _databaseFuture;

  Future<Database> get database async {
    try {
      return await (_databaseFuture ??= _open());
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final databasePath = path.join(await getDatabasesPath(), 'kaq_pos.db');

    return openDatabase(
      databasePath,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL,
            password_hash TEXT NOT NULL, 
            display_name TEXT NOT NULL,
            salt TEXT NOT NULL,
            kdf_params TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1))
          )
        ''');

        await db.execute('''
          CREATE TABLE local_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            issued_at TEXT NOT NULL,
            last_seen_at TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1
              CHECK (is_active IN (0, 1)),
            FOREIGN KEY (user_id) REFERENCES users(id)
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_local_sessions_user
          ON local_sessions(user_id, is_active)
        ''');

        await _createPosTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createPosTables(db);
      },
    );
  }

  Future<void> _createPosTables(Database db) async {
    for (final table in ['products', 'addons']) {
      await db.execute('''
        CREATE TABLE $table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price INTEGER NOT NULL CHECK (price >= 0),
          stock INTEGER NOT NULL CHECK (stock >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        )
      ''');
    }
    await db.execute('''
      CREATE TABLE product_addons (
        product_id INTEGER NOT NULL REFERENCES products(id),
        addon_id INTEGER NOT NULL REFERENCES addons(id),
        PRIMARY KEY (product_id, addon_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE shop_details (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        address TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_id TEXT NOT NULL REFERENCES users(id),
        cashier_name TEXT NOT NULL,
        shop_name TEXT NOT NULL,
        shop_address TEXT NOT NULL,
        sold_at TEXT NOT NULL,
        items_json TEXT NOT NULL,
        subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
        discount INTEGER NOT NULL CHECK (discount BETWEEN 0 AND subtotal),
        total INTEGER NOT NULL CHECK (total = subtotal - discount),
        cash INTEGER NOT NULL CHECK (cash >= total),
        change_due INTEGER NOT NULL CHECK (change_due = cash - total)
      )
    ''');
  }
}
