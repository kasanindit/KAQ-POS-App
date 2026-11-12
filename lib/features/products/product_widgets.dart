import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';
import 'package:pos_app/data/repository/pos_repository.dart';

const productRadius = BorderRadius.all(Radius.circular(8));
const productShape = RoundedRectangleBorder(borderRadius: productRadius);

class CategoryFilters extends StatelessWidget {
  const CategoryFilters({
    required this.catalog,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Catalog catalog;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filters = <(int?, String)>[
      (null, 'Semua'),
      for (final category in catalog.categories) (category.id, category.name),
      if (catalog.availableCategory(0) != null) (0, 'Tanpa kategori'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (id, name) in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name),
                showCheckmark: false,
                selected: id == selected,
                selectedColor: colors.primary.withValues(alpha: 0.13),
                shape: productShape,
                onSelected: (_) => onChanged(id),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductPhoto extends StatefulWidget {
  const ProductPhoto({
    required this.repository,
    required this.product,
    super.key,
  });

  final PosRepository repository;
  final Product product;

  @override
  State<ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<ProductPhoto> {
  Future<Uint8List?>? _photo;

  void _load() {
    final product = widget.product;
    _photo = product.photoVersion == null
        ? null
        : widget.repository.productPhoto(product.id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.photoVersion != widget.product.photoVersion) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    key: ValueKey((widget.product.id, widget.product.photoVersion)),
    future: _photo,
    builder: (context, snapshot) => ProductPhotoFrame(bytes: snapshot.data),
  );
}

class ProductPhotoFrame extends StatelessWidget {
  const ProductPhotoFrame({this.bytes, this.placeholderLabel, super.key});

  final Uint8List? bytes;
  final String? placeholderLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: colors.primary),
            if (placeholderLabel != null) ...[
              const SizedBox(height: 8),
              Text(placeholderLabel!),
            ],
          ],
        ),
      ),
    );
    final photo = bytes;
    return ClipRRect(
      borderRadius: productRadius,
      child: photo == null
          ? placeholder
          : Image.memory(
              photo,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}
