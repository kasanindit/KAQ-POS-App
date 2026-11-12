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

  void _showAddedToCart(Product product) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} ditambahkan ke keranjang'),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _add(Product product) async {
    final options = widget.pos.catalog.addonsFor(product.id);
    if (options.isEmpty) {
      try {
        widget.pos.add(product, []);
        _showAddedToCart(product);
      } on PosException catch (error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _OrderDialog(product: product, addons: options, pos: widget.pos),
    );
    if (added == true && mounted) {
      _showAddedToCart(product);
    }
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
                    Text('Nama Kasir: ${widget.cashier}'),
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

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({
    required this.product,
    required this.addons,
    required this.pos,
  });

  final Product product;
  final List<Addon> addons;
  final PosController pos;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _quantities = <int, int>{};
  String? _error;

  void _setQuantity(Addon addon, int quantity) => setState(() {
    _quantities[addon.id] = quantity;
    _error = null;
  });

  void _submit() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    try {
      widget.pos.add(widget.product, [
        for (final addon in widget.addons)
          if ((_quantities[addon.id] ?? 0) > 0)
            (addon: addon, quantity: _quantities[addon.id]!),
      ]);
    } catch (error) {
      setState(() => _error = posError(error));
      return;
    }
    Navigator.pop<bool>(context, true);
  }

  Widget _addonRow(Addon addon, TextTheme text) {
    final quantity = _quantities[addon.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addon.name, style: text.titleSmall),
                Text(
                  '+${rupiah(addon.price)} · Stok ${addon.stock}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QuantityStepper(
            name: addon.name,
            quantity: quantity,
            onDecrease: quantity == 0
                ? null
                : () => _setQuantity(addon, quantity - 1),
            onIncrease: quantity >= addon.stock
                ? null
                : () => _setQuantity(addon, quantity + 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 440),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        namesRoute: true,
        label: 'Pesan ${product.name}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: text.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                rupiah(product.price),
                                style: text.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stok ${product.stock}',
                            textAlign: TextAlign.end,
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text('Add-on', style: text.titleMedium),
                    const SizedBox(height: 4),
                    for (final addon in widget.addons) _addonRow(addon, text),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error case final message?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Text(
                        message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Tambah ke keranjang'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
