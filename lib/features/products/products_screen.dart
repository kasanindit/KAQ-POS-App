import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';
import 'package:pos_app/features/products/product_editor_screen.dart';
import 'package:pos_app/features/products/product_widgets.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({required this.pos, super.key});

  final PosController pos;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  int? _categoryId;

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _categoryId = widget.pos.catalog.availableCategory(_categoryId);
  }

  void _editProduct([Product? product]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductEditorScreen(pos: widget.pos, product: product),
      ),
    );
  }

  Future<void> _editCategory([Category? category]) async {
    var name = category?.name ?? '';
    await showPosForm<bool>(
      context,
      title: category == null ? 'Tambah kategori' : 'Ubah kategori',
      shape: productShape,
      fields: TextFormField(
        initialValue: name,
        decoration: const InputDecoration(labelText: 'Nama kategori'),
        maxLength: 60,
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'Nama kategori wajib diisi.' : null,
        onChanged: (value) => name = value,
      ),
      submit: () async {
        await widget.pos.repository.saveCategory((
          id: category?.id ?? 0,
          name: name.trim(),
        ));
        await widget.pos.load();
        return true;
      },
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final used = widget.pos.catalog.products.any(
      (product) => product.categoryId == category.id,
    );
    await showPosForm<bool>(
      context,
      title: 'Hapus kategori ${category.name}?',
      fields: Text(
        used
            ? 'Produk di kategori ini akan masuk ke Tanpa kategori.'
            : 'Kategori akan dihapus dari katalog.',
      ),
      shape: productShape,
      action: 'Hapus',
      submit: () async {
        await widget.pos.repository.deleteCategory(category.id);
        await widget.pos.load();
        return true;
      },
    );
  }

  Widget _manageCategories(List<Category> categories) => Card(
    margin: EdgeInsets.zero,
    shape: productShape,
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      shape: productShape,
      collapsedShape: productShape,
      leading: const Icon(Icons.category_outlined),
      title: const Text('Kelola kategori'),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in categories)
          ListTile(
            title: Text(category.name),
            onTap: () => _editCategory(category),
            trailing: PopupMenuButton<bool>(
              tooltip: 'Kelola kategori ${category.name}',
              shape: productShape,
              onSelected: (edit) {
                if (edit) {
                  _editCategory(category);
                } else {
                  _deleteCategory(category);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: true, child: Text('Ubah')),
                PopupMenuItem(value: false, child: Text('Hapus')),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(shape: productShape),
            onPressed: _editCategory,
            icon: const Icon(Icons.add),
            label: const Text('Tambah kategori'),
          ),
        ),
      ],
    ),
  );

  Widget _productCard(Product item, Catalog catalog) {
    final categoryName =
        catalog.categories
            .where((category) => category.id == item.categoryId)
            .firstOrNull
            ?.name ??
        'Tanpa kategori';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: productShape,
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: ProductPhoto(repository: widget.pos.repository, product: item),
        ),
        title: Text(item.name),
        subtitle: Text(
          '$categoryName\n${rupiah(item.price)} · Stok ${item.stock}',
        ),
        isThreeLine: true,
        onTap: () => _editProduct(item),
        trailing: PopupMenuButton<bool>(
          tooltip: 'Kelola ${item.name}',
          shape: productShape,
          onSelected: (edit) {
            if (edit) {
              _editProduct(item);
            } else {
              confirmDeleteProduct(context, widget.pos, item);
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
  Widget build(BuildContext context) {
    final catalog = widget.pos.catalog;
    final products = catalog.productsIn(_categoryId).toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PosHeading(
                  'Produk',
                  action: FilledButton.icon(
                    style: FilledButton.styleFrom(shape: productShape),
                    onPressed: _editProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah produk'),
                  ),
                ),
                const SizedBox(height: 12),
                _manageCategories(catalog.categories),
                const SizedBox(height: 12),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: products.isEmpty
              ? SliverToBoxAdapter(
                  child: PosEmpty(
                    Icons.inventory_2_outlined,
                    catalog.products.isEmpty
                        ? 'Belum ada produk.'
                        : 'Kategori ini belum punya produk.',
                  ),
                )
              : SliverList.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _productCard(products[index], catalog),
                ),
        ),
      ],
    );
  }
}
