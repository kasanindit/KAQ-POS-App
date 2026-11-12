import 'dart:convert';
import 'dart:typed_data';

import 'package:pos_app/data/database/app_database.dart';
import 'package:pos_app/data/model/auth.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:sqflite/sqflite.dart';

class PosRepository {
  PosRepository(this._database);

  final AppDatabase _database;

  Future<Catalog> catalog() async {
    final db = await _database.database;
    return db.transaction(_readCatalog);
  }

  Future<Catalog> _readCatalog(DatabaseExecutor db) async {
    final products = await db.rawQuery('''
      SELECT p.*, f.revision AS photo_version
      FROM products p LEFT JOIN product_photos f ON f.product_id = p.id
      WHERE p.is_active = 1 ORDER BY p.name COLLATE NOCASE, p.id
    ''');
    final addons = await db.query(
      'addons',
      where: 'is_active = 1',
      orderBy: 'name COLLATE NOCASE, id',
    );
    final categories = await db.query(
      'categories',
      orderBy: 'name COLLATE NOCASE, id',
    );
    final rows = await db.query('product_addons');
    final links = <int, Set<int>>{};
    for (final row in rows) {
      links
          .putIfAbsent(row['product_id'] as int, () => <int>{})
          .add(row['addon_id'] as int);
    }
    return Catalog(
      [
        for (final row in products)
          (
            id: row['id'] as int,
            name: row['name'] as String,
            price: row['price'] as int,
            stock: row['stock'] as int,
            categoryId: row['category_id'] as int?,
            photoVersion: row['photo_version'] as int?,
          ),
      ],
      [
        for (final row in addons)
          (
            id: row['id'] as int,
            name: row['name'] as String,
            price: row['price'] as int,
            stock: row['stock'] as int,
          ),
      ],
      links,
      categories: [
        for (final row in categories)
          (id: row['id'] as int, name: row['name'] as String),
      ],
    );
  }

  Future<void> saveProduct(
    Product product,
    List<Addon> addons, {
    PhotoChange? photo,
  }) async {
    if (product.categoryId == null) {
      throw const PosException('Pilih kategori produk.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final id = await _saveMaster(txn, 'products', product.id, {
        'name': product.name,
        'price': product.price,
        'stock': product.stock,
        'category_id': product.categoryId,
      });
      final previousAddons = await _linkedAddons(txn, id);
      await txn.delete(
        'product_addons',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      for (final addon in addons) {
        final addonId = await _saveMaster(txn, 'addons', addon.id, {
          'name': addon.name,
          'price': addon.price,
          'stock': addon.stock,
        });
        await txn.insert('product_addons', {
          'product_id': id,
          'addon_id': addonId,
        });
      }
      await _deleteUnusedAddons(txn, previousAddons);
      if (photo != null) await _savePhoto(txn, id, photo.bytes);
    });
  }

  Future<Uint8List?> productPhoto(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'product_photos',
      columns: ['bytes'],
      where: 'product_id = ?',
      whereArgs: [id],
    );
    return rows.firstOrNull?['bytes'] as Uint8List?;
  }

  Future<void> _savePhoto(Transaction txn, int id, Uint8List? bytes) async {
    if (bytes == null) {
      await txn.delete(
        'product_photos',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      return;
    }
    final updated = await txn.rawUpdate(
      'UPDATE product_photos SET bytes = ?, revision = revision + 1 WHERE product_id = ?',
      [bytes, id],
    );
    if (updated == 0) {
      await txn.insert('product_photos', {'product_id': id, 'bytes': bytes});
    }
  }

  Future<int> _saveMaster(
    DatabaseExecutor db,
    String table,
    int id,
    Map<String, Object?> values,
  ) async {
    if (id == 0) return db.insert(table, values);
    final updated = await db.update(
      table,
      values,
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
    );
    if (updated == 0) throw const PosException('Data sudah dihapus.');
    return id;
  }

  Future<void> deleteProduct(int id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final addonIds = await _linkedAddons(txn, id);
      await txn.delete(
        'product_addons',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      await _deleteUnusedAddons(txn, addonIds);
    });
  }

  Future<Iterable<int>> _linkedAddons(Transaction txn, int id) async {
    final rows = await txn.query(
      'product_addons',
      columns: ['addon_id'],
      where: 'product_id = ?',
      whereArgs: [id],
    );
    return rows.map((row) => row['addon_id'] as int);
  }

  Future<void> _deleteUnusedAddons(Transaction txn, Iterable<int> ids) async {
    for (final id in ids) {
      await txn.rawDelete(
        '''
        DELETE FROM addons WHERE id = ?
        AND NOT EXISTS (SELECT 1 FROM product_addons WHERE addon_id = addons.id)
      ''',
        [id],
      );
    }
  }

  Future<void> saveCategory(Category category) async {
    final db = await _database.database;
    final values = {'name': category.name.trim()};
    try {
      if (category.id == 0) {
        await db.insert('categories', values);
      } else {
        final updated = await db.update(
          'categories',
          values,
          where: 'id = ?',
          whereArgs: [category.id],
        );
        if (updated == 0) throw const PosException('Kategori sudah dihapus.');
      }
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const PosException('Nama kategori sudah digunakan.');
      }
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    final db = await _database.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<Shop> shop() async => _readShop(await _database.database);

  Future<Shop> _readShop(DatabaseExecutor db) async {
    final rows = await db.query('shop_details', where: 'id = 1');
    final row = rows.firstOrNull;
    final name = row?['name'] as String? ?? '';
    return (
      name: name.isEmpty ? 'KAQ POS' : name,
      address: row?['address'] as String? ?? '',
    );
  }

  Future<void> saveShop(Shop shop) async {
    final db = await _database.database;
    await db.insert('shop_details', {
      'id': 1,
      'name': shop.name,
      'address': shop.address,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Sale>> sales() async {
    final db = await _database.database;
    final rows = await db.query('sales', orderBy: 'id DESC');
    return rows.map(_saleFromRow).toList();
  }

  Future<Sale> checkout(
    AuthUser cashier,
    List<CartLine> lines,
    PaymentInput input,
  ) async {
    if (lines.isEmpty) throw const PosException('Keranjang masih kosong.');
    final db = await _database.database;
    return db.transaction((txn) async {
      final stock = checkCart(await _readCatalog(txn), lines);
      final payment = Payment(
        lines.fold(0, (sum, line) => sum + line.total),
        input,
      );
      final shop = await _readShop(txn);
      await _deductStock(txn, 'products', stock.products);
      await _deductStock(txn, 'addons', stock.addons);

      final row = <String, Object?>{
        'cashier_id': cashier.id,
        'cashier_name': cashier.displayName,
        'shop_name': shop.name,
        'shop_address': shop.address,
        'sold_at': DateTime.now().toUtc().toIso8601String(),
        'subtotal': payment.subtotal,
        'discount': payment.discount,
        'total': payment.total,
        'cash': payment.cash,
        'change_due': payment.change,
        'items_json': jsonEncode([
          for (final line in lines)
            {
              'name': line.product.name,
              'price': line.product.price,
              'quantity': line.quantity,
              'total': line.total,
              'addons': [
                for (final item in line.addons)
                  {
                    'name': item.addon.name,
                    'price': item.addon.price,
                    'quantity': item.quantity,
                  },
              ],
            },
        ]),
      };
      final id = await txn.insert('sales', row);
      return _saleFromRow({'id': id, ...row});
    });
  }

  Future<void> _deductStock(
    Transaction txn,
    String table,
    Map<int, int> quantities,
  ) async {
    for (final entry in quantities.entries) {
      final updated = await txn.rawUpdate(
        'UPDATE $table SET stock = stock - ? '
        'WHERE id = ? AND is_active = 1 AND stock >= ?',
        [entry.value, entry.key, entry.value],
      );
      if (updated == 0) {
        throw const PosException('Stok berubah. Periksa keranjang.');
      }
    }
  }

  Sale _saleFromRow(Map<String, Object?> row) {
    final items = (jsonDecode(row['items_json'] as String) as List)
        .cast<Map<String, dynamic>>();
    return Sale(
      id: row['id'] as int,
      soldAt: DateTime.parse(row['sold_at'] as String).toLocal(),
      cashier: row['cashier_name'] as String,
      shop: (
        name: row['shop_name'] as String,
        address: row['shop_address'] as String,
      ),
      subtotal: row['subtotal'] as int,
      discount: row['discount'] as int,
      total: row['total'] as int,
      cash: row['cash'] as int,
      change: row['change_due'] as int,
      items: [
        for (final item in items)
          (
            name: item['name'] as String,
            price: item['price'] as int,
            quantity: item['quantity'] as int,
            total: item['total'] as int,
            addons: [
              for (final addon in item['addons'] as List)
                (
                  name: addon['name'] as String,
                  price: addon['price'] as int,
                  quantity: addon['quantity'] as int,
                ),
            ],
          ),
      ],
    );
  }
}
