import 'package:flutter/foundation.dart';

typedef Product = ({
  int id,
  String name,
  int price,
  int stock,
  int? categoryId,
  int? photoVersion,
});
typedef Addon = ({int id, String name, int price, int stock});
typedef Category = ({int id, String name});
typedef PhotoChange = ({Uint8List? bytes});
typedef CartAddon = ({Addon addon, int quantity});
typedef Shop = ({String name, String address});

class Catalog {
  const Catalog(
    this.products,
    this.addons,
    this.links, {
    this.categories = const [],
  });

  final List<Product> products;
  final List<Addon> addons;
  final Map<int, Set<int>> links;
  final List<Category> categories;

  Iterable<Product> productsIn(int? categoryId) => categoryId == null
      ? products
      : products.where((product) => (product.categoryId ?? 0) == categoryId);

  int? availableCategory(int? id) {
    if (id == 0 && products.any((product) => product.categoryId == null)) {
      return 0;
    }
    return categories.any((category) => category.id == id) ? id : null;
  }

  List<Addon> addonsFor(int productId) {
    final ids = links[productId];
    return addons.where((addon) => ids?.contains(addon.id) ?? false).toList();
  }
}

class CartLine {
  const CartLine(this.product, this.addons, this.quantity);

  final Product product;
  final List<CartAddon> addons;
  final int quantity;

  int get total =>
      quantity *
      (product.price +
          addons.fold(
            0,
            (sum, item) => sum + item.addon.price * item.quantity,
          ));

  bool matches(Product other, List<CartAddon> options) =>
      product.id == other.id &&
      mapEquals(
        {for (final item in addons) item.addon.id: item.quantity},
        {for (final item in options) item.addon.id: item.quantity},
      );
}

/// Checks aggregated stock and ensures the customer pays the displayed prices.
({Map<int, int> products, Map<int, int> addons}) checkCart(
  Catalog catalog,
  List<CartLine> lines,
) {
  final products = {
    for (final product in catalog.products) product.id: product,
  };
  final addons = {for (final addon in catalog.addons) addon.id: addon};
  final productQty = <int, int>{};
  final addonQty = <int, int>{};

  for (final line in lines) {
    if (line.quantity < 1 || line.addons.any((item) => item.quantity < 1)) {
      throw const PosException('Jumlah item harus lebih dari nol.');
    }
    final product = products[line.product.id];
    if (product == null ||
        product.price != line.product.price ||
        product.name != line.product.name) {
      throw PosException(
        'Produk ${line.product.name} berubah. Hapus dan pilih ulang.',
      );
    }
    final required = (productQty[product.id] ?? 0) + line.quantity;
    if (required > product.stock) {
      throw PosException('Stok ${product.name} hanya ${product.stock}.');
    }
    productQty[product.id] = required;

    for (final item in line.addons) {
      final addon = addons[item.addon.id];
      if (addon == null ||
          addon.name != item.addon.name ||
          addon.price != item.addon.price ||
          !(catalog.links[product.id]?.contains(addon.id) ?? false)) {
        throw PosException(
          'Add-on ${item.addon.name} berubah. Hapus dan pilih ulang.',
        );
      }
      final required =
          (addonQty[addon.id] ?? 0) + item.quantity * line.quantity;
      if (required > addon.stock) {
        throw PosException('Stok add-on ${addon.name} hanya ${addon.stock}.');
      }
      addonQty[addon.id] = required;
    }
  }
  return (products: productQty, addons: addonQty);
}

class PosException implements Exception {
  const PosException(this.message);
  final String message;
}

enum DiscountMode { fixed, percent }

typedef PaymentInput = ({DiscountMode mode, int discount, int cash});

class Payment {
  Payment(this.subtotal, PaymentInput input)
    : discount = input.mode == DiscountMode.percent
          ? (subtotal * input.discount + 5000) ~/ 10000
          : input.discount,
      cash = input.cash {
    if (input.discount < 0 ||
        (input.mode == DiscountMode.percent && input.discount > 10000) ||
        discount > subtotal) {
      throw const PosException('Diskon melebihi batas.');
    }
    if (cash < total) throw const PosException('Uang diterima kurang.');
  }

  final int subtotal;
  final int discount;
  final int cash;
  int get total => subtotal - discount;
  int get change => cash - total;
}

typedef ReceiptAddon = ({String name, int price, int quantity});
typedef ReceiptItem = ({
  String name,
  int price,
  int quantity,
  int total,
  List<ReceiptAddon> addons,
});

class Sale {
  const Sale({
    required this.id,
    required this.soldAt,
    required this.cashier,
    required this.shop,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.cash,
    required this.change,
  });

  final int id;
  final DateTime soldAt;
  final String cashier;
  final Shop shop;
  final List<ReceiptItem> items;
  final int subtotal;
  final int discount;
  final int total;
  final int cash;
  final int change;

  String get receiptNumber => 'KAQ-${id.toString().padLeft(6, '0')}';
}

String rupiah(int amount) =>
    'Rp${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
