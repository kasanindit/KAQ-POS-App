import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_app/data/database/app_database.dart';
import 'package:pos_app/data/model/auth.dart';
import 'package:pos_app/data/model/password_service.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/data/repository/auth_repository.dart';
import 'package:pos_app/data/repository/pos_repository.dart';
import 'package:pos_app/features/login/login_screen.dart';
import 'package:pos_app/features/pos/cashier_screen.dart';
import 'package:pos_app/features/products/products_screen.dart';
import 'package:pos_app/main.dart';
import 'package:pos_app/utils/routes/route_name.dart';

void main() {
  late _FakeAuthRepository repository;
  late _FakePosRepository posRepository;

  setUp(() {
    repository = _FakeAuthRepository();
    Get.put<AuthRepository>(repository, permanent: true);
    posRepository = _FakePosRepository();
    Get.put<PosRepository>(posRepository, permanent: true);
  });

  tearDown(() => Get.reset());

  testWidgets('register, log in to Cashier, then log out', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final registerLink = find.text('Belum punya akun? Daftar sekarang');
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Kasir Satu');
    await tester.enterText(fields.at(1), 'kasir01');
    await tester.enterText(fields.at(2), 'password01');
    await tester.enterText(fields.at(3), 'password01');
    final registerButton = find.widgetWithText(FilledButton, 'Buat akun');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, RouteName.login);
    expect(repository.registeredUser?.username, 'kasir01');

    await tester.enterText(fields.at(0), 'kasir01');
    await tester.enterText(fields.at(1), 'password01');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk ke Kasir'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, RouteName.cashier);
    expect(find.byType(CashierScreen), findsOneWidget);
    expect(find.text('Kasir: Kasir Satu'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(Get.key.currentState!.canPop(), isFalse);

    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(repository.sessionUser, isNull);
    expect(Get.key.currentState!.canPop(), isFalse);
  });

  testWidgets('an existing session opens Cashier at startup', (tester) async {
    repository.sessionUser = const AuthUser(
      id: 'existing-cashier',
      username: 'kasir01',
      displayName: 'Kasir Satu',
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(Get.currentRoute, RouteName.cashier);
    expect(find.byType(CashierScreen), findsOneWidget);
  });

  testWidgets('Products redirects to Login without a session', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    Get.toNamed(RouteName.products);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, RouteName.login);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProductsScreen), findsNothing);
  });

  testWidgets('new master data appears in Cashier with its linked add-on', (
    tester,
  ) async {
    repository.sessionUser = const AuthUser(
      id: 'cashier',
      username: 'kasir01',
      displayName: 'Kasir Satu',
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Produk'));
    await tester.pumpAndSettle();

    Future<void> tapText(String label) async {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> enterField(String label, String text) async {
      await tester.enterText(find.widgetWithText(TextFormField, label), text);
    }

    await tapText('Tambah add-on');
    await enterField('Nama add-on', 'Madu');
    await enterField('Harga tambahan (Rp)', '1000');
    await enterField('Stok', '5');
    await tapText('Simpan');
    expect(find.text('Madu'), findsOneWidget);

    await tapText('Tambah produk');
    await enterField('Nama produk', 'Teh');
    await enterField('Harga (Rp)', '8000');
    await enterField('Stok', '9');
    final addonCheckbox = find.widgetWithText(CheckboxListTile, 'Madu');
    await tester.ensureVisible(addonCheckbox);
    await tester.tap(addonCheckbox);
    await tester.pumpAndSettle();
    await tapText('Simpan');

    await tester.tap(find.widgetWithText(NavigationDestination, 'Kasir'));
    await tester.pumpAndSettle();
    expect(find.text('Stok 9'), findsOneWidget);
    await tapText('Teh');
    expect(find.text('Pilihan add-on per produk'), findsOneWidget);
    expect(find.text('+Rp1.000 · Stok 5'), findsOneWidget);
  });

  testWidgets('tabs preserve the cart and a paid sale opens from history', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository.sessionUser = const AuthUser(
      id: 'cashier',
      username: 'kasir01',
      displayName: 'Kasir Satu',
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final product = find.text('Kopi Susu');
    await tester.tap(product);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah Oat'));
    await tester.tap(find.text('Tambah ke keranjang'));
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);

    Future<void> selectTab(String label) async {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
    }

    await selectTab('Produk');
    expect(find.text('Tambah produk'), findsOneWidget);
    expect(find.byTooltip('Buka keranjang'), findsNothing);
    await selectTab('Laporan');
    expect(find.text('0 transaksi berhasil'), findsOneWidget);
    await selectTab('Kasir');
    await tester.tap(find.byTooltip('Buka keranjang'));
    await tester.pumpAndSettle();
    expect(find.text('Keranjang'), findsOneWidget);
    expect(find.text('Kopi Susu'), findsOneWidget);
    await tester.tap(find.byTooltip('Tambah Kopi Susu'));
    await tester.pumpAndSettle();
    expect(find.text('Rp24.000'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Buka keranjang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar tunai'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Diskon (Rp)'),
      '4000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tunai diterima (Rp)'),
      '25000',
    );
    await tester.tap(find.text('Selesaikan transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Struk transaksi'), findsOneWidget);
    expect(find.text('Rp5.000'), findsOneWidget);
    expect(posRepository.completed.single.total, 20000);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    await selectTab('Laporan');
    expect(find.text('1 transaksi berhasil'), findsOneWidget);
    await tester.tap(find.text('Riwayat transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KAQ-000001'));
    await tester.pumpAndSettle();
    expect(find.text('Struk transaksi'), findsOneWidget);
    expect(find.text('Kasir: Kasir Satu'), findsOneWidget);
    expect(find.text('+ Oat · 1 × Rp2.000 per produk'), findsOneWidget);
    expect(find.text('Rp5.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakePosRepository extends PosRepository {
  _FakePosRepository() : super(AppDatabase());

  final completed = <Sale>[];
  Catalog _catalog = const Catalog(
    [(id: 1, name: 'Kopi Susu', price: 10000, stock: 3)],
    [(id: 1, name: 'Oat', price: 2000, stock: 2)],
    {
      1: {1},
    },
  );

  @override
  Future<Catalog> catalog() async => _catalog;

  @override
  Future<Shop> shop() async => (name: 'Toko QA', address: 'Jalan Melati');

  @override
  Future<void> saveProduct(Product product, Set<int> addonIds) async {
    _catalog = Catalog(
      [
        ..._catalog.products,
        (id: 2, name: product.name, price: product.price, stock: product.stock),
      ],
      _catalog.addons,
      {..._catalog.links, 2: addonIds},
    );
  }

  @override
  Future<void> saveAddon(Addon addon) async {
    _catalog = Catalog(_catalog.products, [
      ..._catalog.addons,
      (id: 2, name: addon.name, price: addon.price, stock: addon.stock),
    ], _catalog.links);
  }

  @override
  Future<List<Sale>> sales() async => completed.toList();

  @override
  Future<Sale> checkout(
    AuthUser cashier,
    List<CartLine> lines,
    PaymentInput input,
  ) async {
    checkCart(_catalog, lines);
    final payment = Payment(
      lines.fold(0, (sum, line) => sum + line.total),
      input,
    );
    final sale = Sale(
      id: completed.length + 1,
      soldAt: DateTime.now(),
      cashier: cashier.displayName,
      shop: await shop(),
      items: [
        for (final line in lines)
          (
            name: line.product.name,
            price: line.product.price,
            quantity: line.quantity,
            total: line.total,
            addons: [
              for (final option in line.addons)
                (
                  name: option.addon.name,
                  price: option.addon.price,
                  quantity: option.quantity,
                ),
            ],
          ),
      ],
      subtotal: payment.subtotal,
      discount: payment.discount,
      total: payment.total,
      cash: payment.cash,
      change: payment.change,
    );
    completed.add(sale);
    return sale;
  }
}

// Keep these navigation tests independent of native storage plugins.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(
        appDatabase: AppDatabase(),
        passwordService: PasswordService(),
        secureStorage: const FlutterSecureStorage(),
      );

  AuthUser? registeredUser;
  AuthUser? sessionUser;
  String? _registeredPassword;

  @override
  Future<void> init() async {}

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String password,
  }) async {
    registeredUser = AuthUser(
      id: 'new-cashier',
      username: username,
      displayName: displayName,
    );
    _registeredPassword = password;
  }

  @override
  Future<AuthUser?> login(String username, String password) async {
    if (username != registeredUser?.username ||
        password != _registeredPassword) {
      return null;
    }
    return sessionUser = registeredUser;
  }

  @override
  Future<AuthUser?> restoreSession() async => sessionUser;

  @override
  Future<void> logout() async {
    sessionUser = null;
  }
}
