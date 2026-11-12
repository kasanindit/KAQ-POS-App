import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({required this.pos, required this.cashier, super.key});

  final PosController pos;
  final String cashier;

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  String _query = '';

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
    final products = widget.pos.catalog.products;
    final filtered = products.where(
      (product) => product.name.toLowerCase().contains(_query),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final available = constraints.maxWidth - posPadding.horizontal;
        final columns = available >= 650 ? 3 : (available >= 320 ? 2 : 1);
        final width = (available - (columns - 1) * gap) / columns;
        return ListView(
          padding: posPadding,
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
            const SizedBox(height: 16),
            if (products.isEmpty)
              const PosEmpty(
                Icons.storefront_outlined,
                'Belum ada produk. Tambahkan dari menu Produk.',
              )
            else if (filtered.isEmpty)
              const PosEmpty(Icons.search_off, 'Produk tidak ditemukan.')
            else
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final product in filtered)
                    SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: product.stock == 0
                              ? null
                              : () => _add(product),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  product.stock == 0
                                      ? Icons.remove_shopping_cart_outlined
                                      : Icons.add_shopping_cart,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(rupiah(product.price)),
                                const SizedBox(height: 4),
                                Text(
                                  product.stock == 0
                                      ? 'Habis'
                                      : 'Stok ${product.stock}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
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
