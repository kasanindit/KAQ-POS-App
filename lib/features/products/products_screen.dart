import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({required this.pos, super.key});

  final PosController pos;

  Future<void> _edit(
    BuildContext context, {
    Product? item,
    required bool addon,
  }) async {
    var name = item?.name ?? '';
    var price = item?.price ?? 0;
    var stock = item?.stock ?? 0;
    final ids = pos.catalog
        .addonsFor(item?.id ?? 0)
        .map((addon) => addon.id)
        .toSet();
    final label = addon ? 'add-on' : 'produk';
    await showPosForm<bool>(
      context,
      title: item == null ? 'Tambah $label' : 'Ubah $label',
      fields: StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: name,
              decoration: InputDecoration(
                labelText: addon ? 'Nama add-on' : 'Nama produk',
              ),
              maxLength: 80,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
              onChanged: (value) => name = value,
            ),
            const SizedBox(height: 8),
            PosNumberField(
              label: addon ? 'Harga tambahan (Rp)' : 'Harga (Rp)',
              initialValue: item?.price.toString(),
              onChanged: (value) => price = value,
            ),
            const SizedBox(height: 12),
            PosNumberField(
              label: 'Stok',
              initialValue: item?.stock.toString(),
              onChanged: (value) => stock = value,
            ),
            if (!addon && pos.catalog.addons.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Pilihan add-on'),
              for (final option in pos.catalog.addons)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.name),
                  subtitle: Text(rupiah(option.price)),
                  value: ids.contains(option.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      ids.add(option.id);
                    } else {
                      ids.remove(option.id);
                    }
                  }),
                ),
            ],
          ],
        ),
      ),
      submit: () async {
        final updated = (
          id: item?.id ?? 0,
          name: name.trim(),
          price: price,
          stock: stock,
        );
        if (addon) {
          await pos.repository.saveAddon(updated);
        } else {
          await pos.repository.saveProduct(updated, ids);
        }
        await pos.load();
        return true;
      },
    );
  }

  Future<void> _archive(
    BuildContext context,
    Product item, {
    required bool addon,
  }) async {
    await showPosForm<bool>(
      context,
      title: 'Hapus ${item.name}?',
      fields: const Text(
        'Item ini akan dihapus dari katalog. Struk lama tetap tersedia.',
      ),
      action: 'Hapus',
      submit: () async {
        if (addon) {
          await pos.repository.archiveAddon(item.id);
        } else {
          await pos.repository.archiveProduct(item.id);
        }
        await pos.load();
        return true;
      },
    );
  }

  Widget _item(BuildContext context, Product item, {required bool addon}) {
    final linked = addon ? const <Addon>[] : pos.catalog.addonsFor(item.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(
          [
            '${rupiah(item.price)} · Stok ${item.stock}',
            if (linked.isNotEmpty) linked.map((item) => item.name).join(', '),
          ].join('\n'),
        ),
        onTap: () => _edit(context, item: item, addon: addon),
        trailing: PopupMenuButton<bool>(
          tooltip: 'Kelola ${item.name}',
          onSelected: (edit) {
            if (edit) {
              _edit(context, item: item, addon: addon);
            } else {
              _archive(context, item, addon: addon);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: true, child: Text('Ubah')),
            PopupMenuItem(value: false, child: Text('Hapus')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: posPadding,
    children: [
      PosHeading(
        'Produk',
        action: FilledButton.icon(
          onPressed: () => _edit(context, addon: false),
          icon: const Icon(Icons.add),
          label: const Text('Tambah produk'),
        ),
      ),
      const SizedBox(height: 12),
      if (pos.catalog.products.isEmpty)
        const PosEmpty(Icons.inventory_2_outlined, 'Belum ada produk.'),
      for (final product in pos.catalog.products)
        _item(context, product, addon: false),
      const SizedBox(height: 24),
      PosHeading(
        'Add-on',
        action: OutlinedButton.icon(
          onPressed: () => _edit(context, addon: true),
          icon: const Icon(Icons.add),
          label: const Text('Tambah add-on'),
        ),
      ),
      const SizedBox(height: 12),
      if (pos.catalog.addons.isEmpty)
        const PosEmpty(Icons.tune, 'Belum ada add-on.'),
      for (final addon in pos.catalog.addons)
        _item(context, addon, addon: true),
    ],
  );
}
