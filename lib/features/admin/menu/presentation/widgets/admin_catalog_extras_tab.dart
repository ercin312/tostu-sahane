import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/media/app_image.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_image_picker_field.dart';

Future<void> showAdminCatalogExtraEditor(
  BuildContext context,
  WidgetRef ref, {
  ProductExtra? extra,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AdminCatalogExtraEditorSheet(extra: extra),
  );
}

class _AdminCatalogExtraEditorSheet extends ConsumerStatefulWidget {
  const _AdminCatalogExtraEditorSheet({this.extra});

  final ProductExtra? extra;

  @override
  ConsumerState<_AdminCatalogExtraEditorSheet> createState() =>
      _AdminCatalogExtraEditorSheetState();
}

class _AdminCatalogExtraEditorSheetState
    extends ConsumerState<_AdminCatalogExtraEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  String? _imageSource;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.extra?.name ?? '');
    _priceController = TextEditingController(
      text: widget.extra != null && widget.extra!.price > 0
          ? widget.extra!.price.toString()
          : '',
    );
    _imageSource = widget.extra?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (name.isEmpty || price == null) return;

    setState(() => _saving = true);
    try {
      if (widget.extra == null) {
        await ref.read(adminCatalogExtrasProvider.notifier).createExtra(
              name: name,
              price: price,
              imageUrl: _imageSource,
            );
      } else {
        await ref.read(adminCatalogExtrasProvider.notifier).updateExtra(
              widget.extra!.copyWith(
                name: name,
                price: price,
                imageUrl: _imageSource,
              ),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.commonError.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.extra != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing
                  ? LocaleKeys.adminEditExtra.tr()
                  : LocaleKeys.adminAddExtra.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminImagePickerField(
              value: _imageSource,
              urlLabelKey: LocaleKeys.adminExtraImageUrl,
              previewHeight: 72,
              previewWidth: 72,
              onChanged: (value) => setState(() => _imageSource = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminExtraName.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminExtraPrice.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(LocaleKeys.commonSave.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminCatalogExtrasTab extends ConsumerWidget {
  const AdminCatalogExtrasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extrasAsync = ref.watch(adminCatalogExtrasProvider);

    return extrasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (extras) {
        if (extras.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                LocaleKeys.adminNoCatalogExtras.tr(),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: extras.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final extra = extras[index];
            return _CatalogExtraListTile(
              extra: extra,
              onEdit: () =>
                  showAdminCatalogExtraEditor(context, ref, extra: extra),
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(LocaleKeys.commonRemove.tr()),
                    content: Text(LocaleKeys.adminDeleteExtraConfirm.tr()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(LocaleKeys.commonCancel.tr()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          LocaleKeys.commonRemove.tr(),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(adminCatalogExtrasProvider.notifier)
                      .deleteExtra(extra.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _CatalogExtraListTile extends StatelessWidget {
  const _CatalogExtraListTile({
    required this.extra,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductExtra extra;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = localizedOrRaw(extra.name);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: extra.imageUrl != null && extra.imageUrl!.isNotEmpty
                      ? AppImage(source: extra.imageUrl, fit: BoxFit.cover)
                      : ColoredBox(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: Icon(
                            Icons.fastfood_outlined,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      FormatUtils.currency(extra.price),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
