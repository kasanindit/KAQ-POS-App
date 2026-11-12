import 'package:flutter/foundation.dart';
import 'package:pos_app/data/model/auth.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/data/repository/pos_repository.dart';

class PosController extends ChangeNotifier {
  PosController(this.repository);

  final PosRepository repository;
  Catalog catalog = const Catalog([], [], {});
  Shop shop = (name: 'KAQ POS', address: '');
  List<Sale> sales = [];
  List<CartLine> _cart = [];
  List<CartLine> get cart => List.unmodifiable(_cart);
  int get itemCount => _cart.fold(0, (sum, line) => sum + line.quantity);
  int get subtotal => _cart.fold(0, (sum, line) => sum + line.total);

  bool loading = true;
  bool paying = false;
  bool _disposed = false;
  String? loadError;

  Future<void> load() async {
    loading = true;
    loadError = null;
    _notify();
    try {
      catalog = await repository.catalog();
      shop = await repository.shop();
      sales = await repository.sales();
    } catch (_) {
      loadError = 'Data kasir gagal dimuat.';
    } finally {
      loading = false;
      _notify();
    }
  }

  void add(Product product, List<CartAddon> addons) {
    final index = _cart.indexWhere((line) => line.matches(product, addons));
    final next = [..._cart];
    if (index == -1) {
      next.add(CartLine(product, addons, 1));
    } else {
      final line = next[index];
      next[index] = CartLine(line.product, line.addons, line.quantity + 1);
    }
    checkCart(catalog, next);
    _cart = next;
    _notify();
  }

  void setQuantity(CartLine line, int quantity) {
    final index = _cart.indexOf(line);
    if (index == -1) return;
    final next = [..._cart];
    if (quantity == 0) {
      next.removeAt(index);
    } else {
      next[index] = CartLine(line.product, line.addons, quantity);
    }
    if (quantity > line.quantity) checkCart(catalog, next);
    _cart = next;
    _notify();
  }

  Future<void> deleteProduct(int id) async {
    await repository.deleteProduct(id);
    _cart.removeWhere((line) => line.product.id == id);
    await load();
  }

  Future<Sale?> checkout(AuthUser cashier, PaymentInput input) async {
    if (paying) return null;
    paying = true;
    _notify();
    try {
      final sale = await repository.checkout(cashier, cart, input);
      _cart = [];
      await load();
      return sale;
    } finally {
      paying = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
