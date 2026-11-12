import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({required this.sales, super.key});

  final List<Sale> sales;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _todayOnly = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sales = _todayOnly
        ? widget.sales
              .where((sale) => DateUtils.isSameDay(sale.soldAt, today))
              .toList()
        : widget.sales;
    final revenue = sales.fold(0, (sum, sale) => sum + sale.total);
    return ListView(
      padding: posPadding,
      children: [
        const PosHeading('Laporan penjualan'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<bool>(
            value: _todayOnly,
            items: const [
              DropdownMenuItem(value: false, child: Text('Semua waktu')),
              DropdownMenuItem(value: true, child: Text('Hari ini')),
            ],
            onChanged: (value) => setState(() => _todayOnly = value ?? false),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total omzet'),
                Text(
                  rupiah(revenue),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(height: 24),
                Text('${sales.length} transaksi berhasil'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Riwayat transaksi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => _HistoryScreen(sales)),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen(this.sales);

  final List<Sale> sales;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat transaksi')),
    body: SafeArea(
      top: false,
      child: sales.isEmpty
          ? const PosEmpty(
              Icons.receipt_long_outlined,
              'Belum ada transaksi pada periode ini.',
            )
          : ListView.builder(
              padding: posPadding,
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(sale.receiptNumber),
                    subtitle: Text(
                      '${_saleTime(context, sale.soldAt)}\n${rupiah(sale.total)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReceiptScreen(sale: sale),
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}

String _saleTime(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(date),
    alwaysUse24HourFormat: true,
  );
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · $time';
}

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({required this.sale, this.justPaid = false, super.key});

  final Sale sale;
  final bool justPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Struk transaksi')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: posPadding,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(sale.shop.name, style: theme.textTheme.headlineSmall),
                    if (sale.shop.address.isNotEmpty) Text(sale.shop.address),
                    const SizedBox(height: 12),
                    Text(
                      sale.receiptNumber,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text('Kasir: ${sale.cashier}'),
                    Text(_saleTime(context, sale.soldAt)),
                    const Divider(height: 24),
                    for (final item in sale.items) ...[
                      Text(item.name, style: theme.textTheme.titleMedium),
                      Text('${item.quantity} × ${rupiah(item.price)}'),
                      for (final addon in item.addons)
                        Text(
                          '+ ${addon.name} · ${addon.quantity} × ${rupiah(addon.price)} per produk',
                        ),
                      PosAmountRow('Jumlah item', item.total),
                      const SizedBox(height: 8),
                    ],
                    const Divider(height: 24),
                    PosAmountRow('Subtotal', sale.subtotal),
                    PosAmountRow('Diskon', sale.discount),
                    PosAmountRow(
                      'Total pembayaran',
                      sale.total,
                      emphasized: true,
                    ),
                    PosAmountRow('Tunai diterima', sale.cash),
                    PosAmountRow('Kembalian', sale.change, emphasized: true),
                  ],
                ),
              ),
            ),
            if (justPaid) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Transaksi baru'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
