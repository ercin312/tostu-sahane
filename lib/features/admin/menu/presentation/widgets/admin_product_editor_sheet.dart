import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../../core/localization/locale_keys.dart';

import '../../../../../core/theme/app_colors.dart';

import '../../../../../core/theme/app_spacing.dart';

import '../../../../../core/utils/localized_text.dart';

import '../../../../../core/widgets/app_button.dart';

import '../../../../../core/widgets/product_thumbnail.dart';

import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_combo_item.dart';

import '../../../../../shared/data/mock/mock_data.dart';

import '../../../presentation/providers/admin_provider.dart';

import '../../../presentation/widgets/admin_image_picker_field.dart';

import 'admin_combo_items_editor.dart';
import 'admin_product_extra_picker.dart';



Future<void> showAdminProductEditor(
  BuildContext context,
  WidgetRef ref, {
  Product? product,
}) async {
  final data = await showModalBottomSheet<_ProductFormData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AdminProductEditorSheet(product: product),
  );

  if (data == null || !context.mounted) return;

  try {
    if (product == null) {
      await ref.read(adminProductsProvider.notifier).createProduct(
            name: data.name,
            description: data.description,
            price: data.price,
            category: data.category,
            imageUrl: data.imageUrl,
            extraIds: data.extraIds,
            isCombo: data.isCombo,
            comboItems: data.comboItems,
            isRecommended: data.isRecommended,
          );
    } else {
      await ref.read(adminProductsProvider.notifier).updateProduct(
            product.copyWith(
              nameKey: data.name,
              descriptionKey: data.description,
              price: data.price,
              category: data.category,
              imageUrl: data.imageUrl,
              extraIds: data.extraIds,
              isCombo: data.isCombo,
              comboItems: data.comboItems,
              isRecommended: data.isRecommended,
            ),
          );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    }
  }
}



class _ProductFormData {

  const _ProductFormData({

    required this.name,

    required this.description,

    required this.price,

    required this.category,

    this.imageUrl,

    this.extraIds = const [],
    this.isCombo = false,
    this.comboItems = const [],
    this.isRecommended = false,
  });

  final String name;
  final String description;
  final double price;
  final ProductCategory category;
  final String? imageUrl;
  final List<String> extraIds;
  final bool isCombo;
  final List<ProductComboItem> comboItems;
  final bool isRecommended;
}



class _AdminProductEditorSheet extends ConsumerStatefulWidget {
  const _AdminProductEditorSheet({
    required this.product,
  });

  final Product? product;



  @override

  ConsumerState<_AdminProductEditorSheet> createState() =>

      _AdminProductEditorSheetState();

}



class _AdminProductEditorSheetState

    extends ConsumerState<_AdminProductEditorSheet> {

  late final TextEditingController _nameController;

  late final TextEditingController _descController;

  late final TextEditingController _priceController;

  late ProductCategory _category;

  late Set<String> _selectedExtraIds;
  late bool _isCombo;
  late List<ProductComboItem> _comboItems;
  late bool _isRecommended;
  String? _imageSource;



  @override

  void initState() {

    super.initState();

    final p = widget.product;

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

    _category = p?.category ?? ProductCategory.tost;

    if (p != null) {
      _selectedExtraIds = Set.of(
        p.extraIds.isNotEmpty ? p.extraIds : p.extras.map((extra) => extra.id),
      );
    } else {
      _selectedExtraIds = MockData.defaultProductExtraIds.toSet();
    }
    _isCombo = p?.isCombo ?? false;
    _isRecommended = p?.isRecommended ?? false;
    _comboItems = List.of(p?.comboItems ?? []);
  }



  @override

  void dispose() {

    _nameController.dispose();

    _descController.dispose();

    _priceController.dispose();
    super.dispose();
  }

  Product get _previewProduct => Product(
        id: widget.product?.id ?? 'preview',
        nameKey: _nameController.text.isEmpty
            ? LocaleKeys.adminProductName
            : _nameController.text,
        descriptionKey: _descController.text,
        price: double.tryParse(_priceController.text) ?? 0,
        category: _isCombo ? ProductCategory.combo : _category,
        imageUrl: _imageSource,
        isCombo: _isCombo,
        comboItems: _comboItems,
      );



  void _save() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty || price == null) return;
    if (_isCombo && _comboItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminComboEmpty.tr())),
      );
      return;
    }

    Navigator.pop(
      context,
      _ProductFormData(
        name: name,
        description: _descController.text.trim(),
        price: price,
        category: _isCombo ? ProductCategory.combo : _category,
        imageUrl: _imageSource,
        extraIds: _selectedExtraIds.toList(),
        isCombo: _isCombo,
        comboItems: _isCombo ? _comboItems : const [],
        isRecommended: _isRecommended,
      ),
    );
  }



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: EdgeInsets.only(

        left: AppSpacing.lg,

        right: AppSpacing.lg,

        top: AppSpacing.md,

        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,

      ),

      child: SingleChildScrollView(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          mainAxisSize: MainAxisSize.min,

          children: [

            Center(

              child: Container(

                width: 40,

                height: 4,

                decoration: BoxDecoration(

                  color: AppColors.divider,

                  borderRadius: BorderRadius.circular(2),

                ),

              ),

            ),

            const SizedBox(height: AppSpacing.md),

            Text(

              widget.product == null

                  ? LocaleKeys.adminAddProduct.tr()

                  : LocaleKeys.adminEditProduct.tr(),

              style: Theme.of(context).textTheme.titleLarge,

            ),

            const SizedBox(height: AppSpacing.lg),

            Center(

              child: ProductThumbnail.fromProduct(

                product: _previewProduct,

                width: 120,

                height: 120,

                borderRadius: 16,

              ),

            ),

            const SizedBox(height: AppSpacing.md),

            AdminImagePickerField(

              value: _imageSource,

              onChanged: (v) => setState(() => _imageSource = v),

            ),

            const SizedBox(height: AppSpacing.sm),

            TextField(

              controller: _nameController,

              decoration: InputDecoration(

                labelText: LocaleKeys.adminProductName.tr(),

              ),

              onChanged: (_) => setState(() {}),

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

              keyboardType: const TextInputType.numberWithOptions(decimal: true),

              decoration: InputDecoration(

                labelText: LocaleKeys.adminProductPrice.tr(),

              ),

            ),

            const SizedBox(height: AppSpacing.sm),

            DropdownButtonFormField<ProductCategory>(
              value: _category,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminProductCategory.tr(),
              ),
              items: [
                DropdownMenuItem(
                  value: ProductCategory.tost,
                  child: Text(LocaleKeys.customerCategoryTost.tr()),
                ),
                DropdownMenuItem(
                  value: ProductCategory.sahanda,
                  child: Text(LocaleKeys.customerCategorySahanda.tr()),
                ),
                DropdownMenuItem(
                  value: ProductCategory.drink,
                  child: Text(LocaleKeys.customerCategoryDrink.tr()),
                ),
                DropdownMenuItem(
                  value: ProductCategory.snack,
                  child: Text(LocaleKeys.customerCategorySnack.tr()),
                ),
              ],
              onChanged: _isCombo ? null : (v) => setState(() => _category = v!),
            ),

            SwitchListTile(
              title: Text(LocaleKeys.adminProductIsCombo.tr()),
              value: _isCombo,
              onChanged: (v) => setState(() => _isCombo = v),
            ),

            if (_isCombo) ...[
              AdminComboItemsEditor(
                items: _comboItems,
                excludeProductId: widget.product?.id,
                onChanged: (items) => setState(() => _comboItems = items),
                onSuggestPrice: (amount) {
                  _priceController.text = amount.toStringAsFixed(2);
                  setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            SwitchListTile(
              title: Text(LocaleKeys.adminProductIsRecommended.tr()),
              value: _isRecommended,
              onChanged: (v) => setState(() => _isRecommended = v),
            ),

            const SizedBox(height: AppSpacing.lg),
            AdminProductExtraPicker(
              selectedIds: _selectedExtraIds,
              onChanged: (ids) => setState(() => _selectedExtraIds = ids),
            ),

            const SizedBox(height: AppSpacing.lg),

            AppButton(
              labelKey: LocaleKeys.commonSave,
              onPressed: _save,
            ),

          ],

        ),

      ),

    );

  }

}
