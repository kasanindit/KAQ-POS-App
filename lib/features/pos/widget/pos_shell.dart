import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_app/data/repository/pos_repository.dart';
import 'package:pos_app/features/login/controller/login_controller.dart';
import 'package:pos_app/features/pos/cart_screen.dart';
import 'package:pos_app/features/pos/cashier_screen.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';
import 'package:pos_app/features/report/reports_screen.dart';
import 'package:pos_app/features/products/products_screen.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';

enum PosTab { cashier, products, reports }

class PosShell extends StatefulWidget {
  const PosShell({this.initialTab = PosTab.cashier, super.key});

  final PosTab initialTab;

  @override
  State<PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<PosShell> {
  final _auth = Get.find<LoginController>();
  late final _pos = PosController(Get.find<PosRepository>());
  late PosTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    _pos.load();
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  Future<void> _showSettings(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject();
    final overlay = Navigator.of(buttonContext).overlay?.context
        .findRenderObject();
    if (button is! RenderBox ||
        overlay is! RenderBox ||
        !button.hasSize ||
        !overlay.hasSize) {
      return;
    }

    // Capture the anchor before the popup route begins layout.
    final anchor = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final editShop = await showMenu<bool>(
      context: buttonContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(value: true, child: Text('Detail toko')),
        PopupMenuItem(value: false, child: Text('Keluar')),
      ],
    );
    if (!mounted || editShop == null) return;

    if (editShop) {
      await _editShop();
    } else {
      await _auth.logout();
    }
  }

  Future<void> _editShop() async {
    var name = _pos.shop.name;
    var address = _pos.shop.address;
    await showPosForm<bool>(
      context,
      title: 'Detail toko',
      fields: Column(
        children: [
          TextFormField(
            initialValue: name,
            decoration: const InputDecoration(labelText: 'Nama toko'),
            maxLength: 80,
            onChanged: (value) => name = value,
          ),
          TextFormField(
            initialValue: address,
            decoration: const InputDecoration(
              labelText: 'Alamat toko (opsional)',
            ),
            maxLength: 200,
            maxLines: 2,
            onChanged: (value) => address = value,
          ),
        ],
      ),
      submit: () async {
        await _pos.repository.saveShop((
          name: name.trim(),
          address: address.trim(),
        ));
        await _pos.load();
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Obx(() {
      final user = _auth.currentUser.value;
      final authError = _auth.error.value;
      final authLoading = _auth.isLoading.value;
      return AnimatedBuilder(
        animation: _pos,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text(
              'KAQ POS',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (_tab == PosTab.cashier)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Buka keranjang',
                    onPressed: user == null || authLoading || _pos.loading
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CartScreen(pos: _pos, cashier: user),
                            ),
                          ),
                    icon: Badge.count(
                      count: _pos.itemCount,
                      isLabelVisible: _pos.itemCount > 0,
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                ),
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Pengaturan',
                  onPressed: authLoading
                      ? null
                      : () => _showSettings(buttonContext),
                  icon: const Icon(Icons.more_vert),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (authError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      authError,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IndexedStack(
                        index: _tab.index,
                        children: [
                          CashierScreen(
                            pos: _pos,
                            cashier: user?.displayName ?? '',
                          ),
                          ProductsScreen(pos: _pos),
                          ReportsScreen(sales: _pos.sales),
                        ],
                      ),
                      if (_pos.loading || _pos.loadError != null)
                        ColoredBox(
                          color: colors.surface,
                          child: Center(
                            child: _pos.loading
                                ? const CircularProgressIndicator()
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_pos.loadError!),
                                      TextButton(
                                        onPressed: _pos.load,
                                        child: const Text('Coba lagi'),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: NavigationBar(
              height: 68,
              backgroundColor: colors.surface,
              indicatorColor: colors.primary.withValues(alpha: 0.13),
              selectedIndex: _tab.index,
              onDestinationSelected: (index) {
                FocusScope.of(context).unfocus();
                setState(() => _tab = PosTab.values[index]);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront, color: colors.primary),
                  label: 'Kasir',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2, color: colors.primary),
                  label: 'Produk',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart, color: colors.primary),
                  label: 'Laporan',
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
