import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/qr_menu_settings.dart';
import '../../../menu/presentation/widgets/admin_product_extra_picker.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_image_picker_field.dart';

/// Bilinen navbar id → ProductCategory (garson / mutfak uyumu).
ProductCategory productCategoryForNavId(String navId) {
  return switch (navId) {
    'tost' => ProductCategory.tost,
    'sahanda' => ProductCategory.sahanda,
    'drink' => ProductCategory.drink,
    'snack' => ProductCategory.snack,
    'combo' => ProductCategory.combo,
    'extra' => ProductCategory.snack,
    _ => ProductCategory.tost,
  };
}

Future<void> showQrMenuProductEditor(
  BuildContext context,
  WidgetRef ref, {
  Product? product,
  required List<QrNavCategory> navCategories,
}) async {
  if (navCategories.isEmpty) return;

  final data = await showModalBottomSheet<_QrProductFormData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _QrMenuProductEditorSheet(
      product: product,
      navCategories: navCategories,
    ),
  );

  if (data == null || !context.mounted) return;

  final category = productCategoryForNavId(data.navCategoryId);
  final qrNavId = data.navCategoryId;

  try {
    if (product == null) {
      await ref.read(adminProductsProvider.notifier).createProduct(
            name: data.name,
            description: data.description,
            price: data.price,
            category: category,
            imageUrl: data.imageUrl,
            extraIds: data.extraIds,
            qrNavCategoryId: qrNavId,
          );
    } else {
      await ref.read(adminProductsProvider.notifier).updateProduct(
            product.copyWith(
              nameKey: data.name,
              descriptionKey: data.description,
              price: data.price,
              category: category,
              imageUrl: data.imageUrl,
              extraIds: data.extraIds,
              qrNavCategoryId: qrNavId,
            ),
          );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.commonSaved.tr())),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.commonError.tr())),
    );
  }
}

class _QrProductFormData {
  const _QrProductFormData({
    required this.name,
    required this.description,
    required this.price,
    required this.navCategoryId,
    this.imageUrl,
    this.extraIds = const [],
  });

  final String name;
  final String description;
  final double price;
  final String navCategoryId;
  final String? imageUrl;
  final List<String> extraIds;
}

class _QrMenuProductEditorSheet extends ConsumerStatefulWidget {
  const _QrMenuProductEditorSheet({
    required this.product,
    required this.navCategories,
  });

  final Product? product;
  final List<QrNavCategory> navCategories;

  @override
  ConsumerState<_QrMenuProductEditorSheet> createState() =>
      _QrMenuProductEditorSheetState();
}

class _QrMenuProductEditorSheetState
    extends ConsumerState<_QrMenuProductEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late String _navCategoryId;
  late Set<String> _selectedExtraIds;
  String? _imageSource;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final cats = widget.navCategories;
    _nameController = TextEditingController(
      text: p != null ? localizedOrRaw(p.nameKey) : '',
    );
    _descController = TextEditingController(
      text: p != null ? localizedOrRaw(p.descriptionKey) : '',
    );
    _priceController = TextEditingController(
      text: p?.price.toString() ?? '',
    );
    _imageSource = p?.imageUrl;
    final preferred = p?.effectiveQrNavCategoryId;
    if (preferred != null && cats.any((c) => c.id == preferred)) {
      _navCategoryId = preferred;
    } else {
      _navCategoryId = cats.first.id;
    }
    _selectedExtraIds = Set.of(
      p?.extraIds.isNotEmpty == true
          ? p!.extraIds
          : (p?.extras.map((e) => e.id) ?? const <String>[]),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    if (name.isEmpty || price == null) return;
    Navigator.pop(
      context,
      _QrProductFormData(
        name: name,
        description: _descController.text.trim(),
        price: price,
        navCategoryId: _navCategoryId,
        imageUrl: _imageSource,
        extraIds: _selectedExtraIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.product == null
                  ? LocaleKeys.adminQrMenuAddProduct.tr()
                  : LocaleKeys.adminQrMenuEditProduct.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminProductName.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminProductDescription.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminProductPrice.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: ValueKey(_navCategoryId),
              initialValue: _navCategoryId,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminQrMenuProductCategory.tr(),
              ),
              items: [
                for (final c in widget.navCategories)
                  DropdownMenuItem(value: c.id, child: Text(c.label)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _navCategoryId = v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AdminImagePickerField(
              value: _imageSource,
              onChanged: (v) => setState(() => _imageSource = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminProductExtraPicker(
              selectedIds: _selectedExtraIds,
              onChanged: (ids) => setState(() => _selectedExtraIds = ids),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _save,
              child: Text(LocaleKeys.commonSave.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
