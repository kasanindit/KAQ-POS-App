import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';
import 'package:pos_app/features/products/product_widgets.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({required this.pos, required this.cashier, super.key});

  final PosController pos;
  final String cashier;

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  String _query = '';
  int? _categoryId;

  @override
  void didUpdateWidget(covariant CashierScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _categoryId = widget.pos.catalog.availableCategory(_categoryId);
  }

  Future<void> _add(Product product) async {
    final options = widget.pos.catalog.addonsFor(product.id);
    if (options.isEmpty) {
      try {
        widget.pos.add(product, []);
      } on PosException catch (error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    final quantities = <int, int>{};
    await showPosForm<bool>(
      context,
      title: product.name,
      action: 'Tambah ke keranjang',
      fields: StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Pilihan add-on per produk'),
            const SizedBox(height: 8),
            for (final addon in options)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addon.name),
                  Text('+${rupiah(addon.price)} · Stok ${addon.stock}'),
                  QuantityStepper(
                    name: addon.name,
                    quantity: quantities[addon.id] ?? 0,
                    onDecrease: (quantities[addon.id] ?? 0) == 0
                        ? null
                        : () => setState(
                            () => quantities[addon.id] =
                                quantities[addon.id]! - 1,
                          ),
                    onIncrease: (quantities[addon.id] ?? 0) >= addon.stock
                        ? null
                        : () => setState(
                            () => quantities[addon.id] =
                                (quantities[addon.id] ?? 0) + 1,
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
      submit: () async {
        widget.pos.add(product, [
          for (final addon in options)
            if ((quantities[addon.id] ?? 0) > 0)
              (addon: addon, quantity: quantities[addon.id]!),
        ]);
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.pos.catalog;
    final filtered = catalog
        .productsIn(_categoryId)
        .where((product) => product.name.toLowerCase().contains(_query))
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final available = constraints.maxWidth - posPadding.horizontal;
        final columns = available >= 650 ? 3 : (available >= 320 ? 2 : 1);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PosHeading('Kasir'),
                    const SizedBox(height: 4),
                    Text('Kasir: ${widget.cashier}'),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cari produk',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    CategoryFilters(
                      catalog: catalog,
                      selected: _categoryId,
                      onChanged: (id) => setState(() => _categoryId = id),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: filtered.isEmpty
                  ? SliverToBoxAdapter(
                      child: catalog.products.isEmpty
                          ? const PosEmpty(
                              Icons.storefront_outlined,
                              'Belum ada produk. Tambahkan dari menu Produk.',
                            )
                          : const PosEmpty(
                              Icons.search_off,
                              'Produk tidak ditemukan.',
                            ),
                    )
                  : SliverList.builder(
                      itemCount: (filtered.length + columns - 1) ~/ columns,
                      itemBuilder: (context, row) => Padding(
                        padding: const EdgeInsets.only(bottom: gap),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0) const SizedBox(width: gap),
                              Expanded(
                                child: row * columns + column < filtered.length
                                    ? _productCard(
                                        context,
                                        filtered[row * columns + column],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _productCard(BuildContext context, Product product) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: productShape,
    child: InkWell(
      onTap: product.stock == 0 ? null : () => _add(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2,
            child: ProductPhoto(
              repository: widget.pos.repository,
              product: product,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(rupiah(product.price)),
                const SizedBox(height: 4),
                Text(product.stock == 0 ? 'Habis' : 'Stok ${product.stock}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.name,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    super.key,
  });

  final String name;
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: onDecrease,
        tooltip: 'Kurangi $name',
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text('$quantity'),
      IconButton(
        onPressed: onIncrease,
        tooltip: 'Tambah $name',
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}
