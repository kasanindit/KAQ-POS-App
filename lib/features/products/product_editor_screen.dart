import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/features/pos/widget/pos_widgets.dart';
import 'package:pos_app/features/products/product_widgets.dart';
import 'package:pos_app/features/shared/controller/pos_controller.dart';

Future<bool> confirmDeleteProduct(
  BuildContext context,
  PosController pos,
  Product product,
) async {
  return await showPosForm<bool>(
        context,
        title: 'Hapus ${product.name}?',
        fields: const Text(
          'Produk, foto, dan add-on yang hanya dipakai produk ini akan dihapus. Struk lama tetap tersedia.',
        ),
        shape: productShape,
        action: 'Hapus',
        submit: () async {
          await pos.deleteProduct(product.id);
          return true;
        },
      ) ??
      false;
}

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({required this.pos, this.product, super.key});

  final PosController pos;
  final Product? product;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name = widget.product?.name ?? '';
  late String _price = widget.product?.price.toString() ?? '';
  late String _stock = widget.product?.stock.toString() ?? '';
  late int? _categoryId = widget.product?.categoryId;
  late final _addons = widget.pos.catalog
      .addonsFor(widget.product?.id ?? 0)
      .map(_AddonDraft.new)
      .toList();
  PhotoChange? _photo;
  bool _saving = false;
  bool _picking = false;

  bool get _busy => _saving || _picking;
  bool get _hasPhoto => _photo == null
      ? widget.product?.photoVersion != null
      : _photo?.bytes != null;
  bool get _canSave =>
      !_busy &&
      _name.trim().isNotEmpty &&
      _categoryId != null &&
      _number(_price) != null &&
      _number(_stock) != null;

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (image == null) return;
      if (await image.length() > 768 * 1024) {
        throw const PosException(
          'Foto terlalu besar. Pilih gambar berukuran lebih kecil.',
        );
      }
      final bytes = await image.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => _photo = (bytes: bytes));
    } catch (error) {
      if (mounted) {
        _showError(
          error is PosException
              ? error.message
              : 'Foto gagal dibuka. Periksa izin atau pilih foto lain.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await Scrollable.ensureVisible(invalid.first.context, alignment: 0.15);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.pos.repository.saveProduct(
        (
          id: widget.product?.id ?? 0,
          name: _name.trim(),
          price: _number(_price)!,
          stock: _number(_stock)!,
          categoryId: _categoryId,
          photoVersion: widget.product?.photoVersion,
        ),
        _addons.map((addon) => addon.toRecord()).toList(),
        photo: _photo,
      );
      await widget.pos.load();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(posError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Product product) async {
    final deleted = await confirmDeleteProduct(context, widget.pos, product);
    if (deleted && mounted) Navigator.pop(context);
  }

  Widget _numberField(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) => TextFormField(
    initialValue: value,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (value) => _number(value ?? '') == null
        ? 'Masukkan angka bulat tanpa pemisah.'
        : null,
    onChanged: onChanged,
  );

  Widget _addonFields(_AddonDraft addon, int index) {
    final catalog = widget.pos.catalog;
    final shared = catalog.links.entries.any(
      (entry) =>
          entry.key != widget.product?.id &&
          entry.value.contains(addon.id) &&
          catalog.products.any((product) => product.id == entry.key),
    );
    return Card(
      key: ObjectKey(addon),
      shape: productShape,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Add-on ${index + 1}')),
                IconButton(
                  tooltip: 'Hapus add-on ${index + 1}',
                  onPressed: () => setState(() => _addons.remove(addon)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (shared)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Nama, harga, dan stok add-on ini dipakai bersama produk lain.',
                ),
              ),
            TextFormField(
              initialValue: addon.name,
              decoration: const InputDecoration(labelText: 'Nama add-on'),
              maxLength: 80,
              validator: _validateName,
              onChanged: (value) => addon.name = value,
            ),
            const SizedBox(height: 8),
            _numberField(
              'Harga tambahan (Rp)',
              addon.price,
              (value) => addon.price = value,
            ),
            const SizedBox(height: 12),
            _numberField(
              'Stok add-on',
              addon.stock,
              (value) => addon.stock = value,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final catalog = widget.pos.catalog;
    final unselected = catalog.addons
        .where((item) => !_addons.any((draft) => draft.id == item.id))
        .toList();
    final cameraSupported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final errorColor = Theme.of(context).colorScheme.error;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(product == null ? 'Tambah produk' : 'Ubah produk'),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: posPadding,
                child: AbsorbPointer(
                  absorbing: _busy,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 2,
                          child: _photo == null && product?.photoVersion != null
                              ? ProductPhoto(
                                  repository: widget.pos.repository,
                                  product: product!,
                                )
                              : ProductPhotoFrame(
                                  bytes: _photo?.bytes,
                                  placeholderLabel: 'Belum ada foto produk',
                                ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              onPressed: cameraSupported && !_busy
                                  ? () => _pickPhoto(ImageSource.camera)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                shape: productShape,
                              ),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Kamera'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pickPhoto(ImageSource.gallery),
                              style: OutlinedButton.styleFrom(
                                shape: productShape,
                              ),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Galeri'),
                            ),
                            if (_hasPhoto)
                              TextButton(
                                style: TextButton.styleFrom(
                                  shape: productShape,
                                ),
                                onPressed: () =>
                                    setState(() => _photo = (bytes: null)),
                                child: const Text('Hapus foto'),
                              ),
                          ],
                        ),
                        if (_picking) const LinearProgressIndicator(),
                        const SizedBox(height: 20),
                        TextFormField(
                          initialValue: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nama produk',
                          ),
                          maxLength: 80,
                          validator: _validateName,
                          onChanged: (value) => setState(() => _name = value),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori produk',
                          ),
                          items: [
                            for (final category in catalog.categories)
                              DropdownMenuItem(
                                value: category.id,
                                child: Text(
                                  category.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: catalog.categories.isEmpty || _busy
                              ? null
                              : (id) => setState(() => _categoryId = id),
                          validator: (id) =>
                              id == null ? 'Pilih kategori produk.' : null,
                        ),
                        if (catalog.categories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Buat kategori terlebih dahulu di menu Produk.',
                            ),
                          ),
                        const SizedBox(height: 12),
                        _numberField(
                          'Harga (Rp)',
                          _price,
                          (value) => setState(() => _price = value),
                        ),
                        const SizedBox(height: 12),
                        _numberField(
                          'Stok',
                          _stock,
                          (value) => setState(() => _stock = value),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Add-on (opsional)',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        for (final (index, addon) in _addons.indexed)
                          _addonFields(addon, index),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: productShape,
                              ),
                              onPressed: () =>
                                  setState(() => _addons.add(_AddonDraft())),
                              icon: const Icon(Icons.add),
                              label: const Text('Tambah add-on'),
                            ),
                            if (unselected.isNotEmpty)
                              PopupMenuButton<Addon>(
                                tooltip: 'Pilih add-on tersimpan',
                                shape: productShape,
                                onSelected: (addon) => setState(
                                  () => _addons.add(_AddonDraft(addon)),
                                ),
                                itemBuilder: (_) => [
                                  for (final addon in unselected)
                                    PopupMenuItem(
                                      value: addon,
                                      child: Text(addon.name),
                                    ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  child: Text('Pilih add-on tersimpan'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: product == null || _busy
                      ? null
                      : () => _delete(product),
                  style: OutlinedButton.styleFrom(
                    shape: productShape,
                    foregroundColor: errorColor,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(shape: productShape),
                  child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _validateName(String? value) =>
    (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null;

int? _number(String value) =>
    RegExp(r'^\d+$').hasMatch(value) ? int.tryParse(value) : null;

class _AddonDraft {
  _AddonDraft([Addon? addon])
    : id = addon?.id ?? 0,
      name = addon?.name ?? '',
      price = addon?.price.toString() ?? '',
      stock = addon?.stock.toString() ?? '';

  final int id;
  String name;
  String price;
  String stock;

  Addon toRecord() => (
    id: id,
    name: name.trim(),
    price: _number(price)!,
    stock: _number(stock)!,
  );
}
