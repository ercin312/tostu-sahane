import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../../core/localization/locale_keys.dart';

import '../../../../../core/theme/app_colors.dart';

import '../../../../../core/theme/app_spacing.dart';

import '../../../../../shared/domain/entities/product_extra.dart';

import '../../../presentation/widgets/admin_image_picker_field.dart';



class AdminProductExtrasEditor extends ConsumerWidget {

  const AdminProductExtrasEditor({

    super.key,

    required this.extras,

    required this.onChanged,

  });



  final List<ProductExtra> extras;

  final ValueChanged<List<ProductExtra>> onChanged;



  void _addExtra() {

    onChanged([

      ProductExtra(

        id: 'ex_${DateTime.now().millisecondsSinceEpoch}',

        name: '',

        price: 0,

      ),

      ...extras,

    ]);

  }



  void _updateExtra(int index, ProductExtra extra) {

    final updated = [...extras];

    updated[index] = extra;

    onChanged(updated);

  }



  void _removeExtra(int index) {

    onChanged([...extras]..removeAt(index));

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Row(

          children: [

            Expanded(

              child: Text(

                LocaleKeys.adminProductExtras.tr(),

                style: Theme.of(context).textTheme.titleMedium?.copyWith(

                      fontWeight: FontWeight.w700,

                    ),

              ),

            ),

            TextButton.icon(

              onPressed: _addExtra,

              icon: const Icon(Icons.add, size: 18),

              label: Text(LocaleKeys.adminAddExtra.tr()),

            ),

          ],

        ),

        if (extras.isEmpty)

          Padding(

            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),

            child: Text(

              LocaleKeys.adminNoExtras.tr(),

              style: Theme.of(context).textTheme.bodySmall?.copyWith(

                    color: AppColors.textSecondary,

                  ),

            ),

          )

        else

          ...extras.asMap().entries.map(

                (entry) => _ExtraEditorCard(

                  key: ValueKey(entry.value.id),

                  extra: entry.value,

                  onChanged: (e) => _updateExtra(entry.key, e),

                  onRemove: () => _removeExtra(entry.key),

                ),

              ),

      ],

    );

  }

}



class _ExtraEditorCard extends StatefulWidget {

  const _ExtraEditorCard({

    super.key,

    required this.extra,

    required this.onChanged,

    required this.onRemove,

  });



  final ProductExtra extra;

  final ValueChanged<ProductExtra> onChanged;

  final VoidCallback onRemove;



  @override

  State<_ExtraEditorCard> createState() => _ExtraEditorCardState();

}



class _ExtraEditorCardState extends State<_ExtraEditorCard> {

  late final TextEditingController _nameController;

  late final TextEditingController _priceController;

  String? _imageSource;



  @override

  void initState() {

    super.initState();

    _nameController = TextEditingController(text: widget.extra.name);

    _priceController = TextEditingController(

      text: widget.extra.price > 0 ? widget.extra.price.toString() : '',

    );

    _imageSource = widget.extra.imageUrl;

  }



  @override

  void dispose() {

    _nameController.dispose();

    _priceController.dispose();

    super.dispose();

  }



  void _emit() {

    widget.onChanged(

      widget.extra.copyWith(

        name: _nameController.text.trim(),

        price: double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,

        imageUrl: _imageSource,

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    return Container(

      margin: const EdgeInsets.only(bottom: AppSpacing.sm),

      padding: const EdgeInsets.all(AppSpacing.sm),

      decoration: BoxDecoration(

        color: AppColors.background,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppColors.divider),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Row(

            children: [

              Expanded(

                child: Text(

                  _nameController.text.isEmpty

                      ? LocaleKeys.adminExtraName.tr()

                      : _nameController.text,

                  style: Theme.of(context).textTheme.titleSmall,

                ),

              ),

              IconButton(

                icon: const Icon(Icons.delete_outline, color: AppColors.error),

                onPressed: widget.onRemove,

              ),

            ],

          ),

          AdminImagePickerField(

            value: _imageSource,

            urlLabelKey: LocaleKeys.adminExtraImageUrl,

            previewHeight: 56,

            previewWidth: 56,

            onChanged: (v) {

              setState(() => _imageSource = v);

              _emit();

            },

          ),

          const SizedBox(height: AppSpacing.sm),

          TextField(

            controller: _nameController,

            decoration: InputDecoration(

              labelText: LocaleKeys.adminExtraName.tr(),

              isDense: true,

            ),

            onChanged: (_) => _emit(),

          ),

          const SizedBox(height: AppSpacing.xs),

          TextField(

            controller: _priceController,

            keyboardType: const TextInputType.numberWithOptions(decimal: true),

            decoration: InputDecoration(

              labelText: LocaleKeys.adminExtraPrice.tr(),

              isDense: true,

            ),

            onChanged: (_) => _emit(),

          ),

        ],

      ),

    );

  }

}


