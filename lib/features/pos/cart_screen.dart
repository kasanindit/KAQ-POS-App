import 'package:flutter/material.dart';
import 'package:pos_app/data/model/auth.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/pos/cashier_screen.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';
import 'package:pos_app/features/report/reports_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({required this.pos, required this.cashier, super.key});

  final PosController pos;
  final AuthUser cashier;

  void _setQuantity(BuildContext context, CartLine line, int quantity) {
    try {
      pos.setQuantity(line, quantity);
    } on PosException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pay(BuildContext context) async {
    var input = (mode: DiscountMode.fixed, discount: 0, cash: 0);
    final sale = await showPosForm<Sale?>(
      context,
      title: 'Pembayaran tunai',
      action: 'Selesaikan transaksi',
      fields: _PaymentFields(
        subtotal: pos.subtotal,
        onChanged: (value) => input = value,
      ),
      submit: () => pos.checkout(cashier, input),
    );
    if (sale != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReceiptScreen(sale: sale, justPaid: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pos,
    builder: (context, _) {
      final lines = pos.cart;
      return Scaffold(
        appBar: AppBar(title: const Text('Keranjang')),
        body: SafeArea(
          top: false,
          child: lines.isEmpty
              ? const PosEmpty(
                  Icons.shopping_cart_outlined,
                  'Keranjang masih kosong.',
                )
              : ListView.builder(
                  padding: posPadding,
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(rupiah(line.product.price)),
                            for (final item in line.addons)
                              Text(
                                '+ ${item.addon.name} · ${item.quantity} × ${rupiah(item.addon.price)} per produk',
                              ),
                            QuantityStepper(
                              name: line.product.name,
                              quantity: line.quantity,
                              onDecrease: () => _setQuantity(
                                context,
                                line,
                                line.quantity - 1,
                              ),
                              onIncrease: () => _setQuantity(
                                context,
                                line,
                                line.quantity + 1,
                              ),
                            ),
                            PosAmountRow('Harga item', line.total),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        bottomNavigationBar: lines.isEmpty
            ? null
            : Material(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PosAmountRow('Subtotal', pos.subtotal, emphasized: true),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: pos.paying ? null : () => _pay(context),
                        child: const Text('Bayar tunai'),
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

class _PaymentFields extends StatefulWidget {
  const _PaymentFields({required this.subtotal, required this.onChanged});

  final int subtotal;
  final ValueChanged<PaymentInput> onChanged;

  @override
  State<_PaymentFields> createState() => _PaymentFieldsState();
}

class _PaymentFieldsState extends State<_PaymentFields> {
  DiscountMode _mode = DiscountMode.fixed;
  String _discount = '';
  int _cash = 0;

  int? get _discountAmount {
    if (_discount.isEmpty) return 0;
    if (_mode == DiscountMode.fixed) {
      return RegExp(r'^\d+$').hasMatch(_discount)
          ? int.tryParse(_discount)
          : null;
    }
    final parts = _discount.replaceAll(',', '.').split('.');
    if (!RegExp(r'^\d{1,3}([.,]\d{1,2})?$').hasMatch(_discount)) return null;
    final fraction = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;
    return int.parse(parts.first) * 100 + fraction;
  }

  void _update() => widget.onChanged((
    mode: _mode,
    discount: _discountAmount ?? -1,
    cash: _cash,
  ));

  @override
  Widget build(BuildContext context) {
    Payment? preview;
    try {
      preview = Payment(widget.subtotal, (
        mode: _mode,
        discount: _discountAmount ?? -1,
        cash: widget.subtotal,
      ));
    } on PosException {
      // The field reports an invalid discount below.
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PosAmountRow('Subtotal', widget.subtotal),
        const SizedBox(height: 8),
        DropdownButtonFormField<DiscountMode>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Jenis diskon'),
          items: const [
            DropdownMenuItem(value: DiscountMode.fixed, child: Text('Rupiah')),
            DropdownMenuItem(
              value: DiscountMode.percent,
              child: Text('Persen'),
            ),
          ],
          onChanged: (mode) {
            setState(() {
              _mode = mode ?? DiscountMode.fixed;
              _discount = '';
            });
            _update();
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(_mode),
          decoration: InputDecoration(
            labelText: _mode == DiscountMode.percent
                ? 'Diskon (%)'
                : 'Diskon (Rp)',
          ),
          keyboardType: TextInputType.numberWithOptions(
            decimal: _mode == DiscountMode.percent,
          ),
          onChanged: (value) {
            setState(() => _discount = value.trim());
            _update();
          },
          validator: (_) => preview == null ? 'Periksa jumlah diskon.' : null,
        ),
        const SizedBox(height: 12),
        PosNumberField(
          label: 'Tunai diterima (Rp)',
          onChanged: (value) {
            setState(() => _cash = value);
            _update();
          },
        ),
        if (preview != null) ...[
          const SizedBox(height: 8),
          PosAmountRow('Total pembayaran', preview.total, emphasized: true),
          if (_cash >= preview.total)
            PosAmountRow('Kembalian', _cash - preview.total),
        ],
      ],
    );
  }
}
