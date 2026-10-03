import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';

Future<void> showPromotionCampaignEditor(
  BuildContext context,
  WidgetRef ref, {
  PromotionCampaign? campaign,
  Future<void> Function(PromotionCampaign campaign)? persist,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _PromotionCampaignEditorSheet(
      campaign: campaign,
      onSave: (data) async {
        try {
          if (persist != null) {
            await persist(data);
          } else {
            await savePromotionCampaign(ref, data);
          }
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(LocaleKeys.adminPromotionSaved.tr())),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(LocaleKeys.commonError.tr())),
            );
          }
        }
      },
    ),
  );
}

enum _CampaignScope { cart, category, products }

class _PromotionCampaignEditorSheet extends ConsumerStatefulWidget {
  const _PromotionCampaignEditorSheet({
    required this.campaign,
    required this.onSave,
  });

  final PromotionCampaign? campaign;
  final Future<void> Function(PromotionCampaign campaign) onSave;

  @override
  ConsumerState<_PromotionCampaignEditorSheet> createState() =>
      _PromotionCampaignEditorSheetState();
}

class _PromotionCampaignEditorSheetState
    extends ConsumerState<_PromotionCampaignEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _valueController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _codeController;
  late final TextEditingController _remainingController;
  late final TextEditingController _buyController;
  late final TextEditingController _freeController;
  late final TextEditingController _searchController;

  late PromotionType _type;
  late bool _autoApply;
  late bool _isActive;
  late bool _firstOrderOnly;
  late _CampaignScope _scope;
  late String _category;
  late List<String> _productIds;
  late List<String> _rewardIds;
  DateTime? _expiresAt;
  DateTime? _startsAt;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    _titleController = TextEditingController(text: campaign?.title ?? '');
    _descriptionController =
        TextEditingController(text: campaign?.description ?? '');
    _valueController = TextEditingController(
      text: campaign?.value == 0 ? '' : '${campaign?.value ?? ''}',
    );
    _maxDiscountController = TextEditingController(
      text: campaign?.maxDiscount == null ? '' : '${campaign!.maxDiscount}',
    );
    _minOrderController = TextEditingController(
      text: campaign?.minOrderAmount == 0
          ? ''
          : '${campaign?.minOrderAmount ?? ''}',
    );
    _codeController = TextEditingController(text: campaign?.code ?? '');
    _remainingController = TextEditingController(
      text: campaign?.remainingUses == null ? '' : '${campaign!.remainingUses}',
    );
    _buyController = TextEditingController(
      text: '${campaign?.buyQuantity == 0 ? 2 : campaign?.buyQuantity ?? 2}',
    );
    _freeController = TextEditingController(
      text: '${campaign?.freeQuantity == 0 ? 1 : campaign?.freeQuantity ?? 1}',
    );
    _searchController = TextEditingController();
    _type = campaign?.type ?? PromotionType.percentDiscount;
    _autoApply = campaign?.autoApply ?? false;
    _isActive = campaign?.isActive ?? true;
    _firstOrderOnly = campaign?.firstOrderOnly ?? false;
    _expiresAt = campaign?.expiresAt;
    _startsAt = campaign?.startsAt;
    _productIds = List<String>.of(campaign?.productIds ?? const []);
    _rewardIds = List<String>.of(campaign?.rewardProductIds ?? const []);
    _category = campaign?.scopedCategory?.name ?? ProductCategory.tost.name;
    if (campaign != null && campaign.productIds.isNotEmpty) {
      _scope = _CampaignScope.products;
    } else if (campaign?.scopedCategory != null) {
      _scope = _CampaignScope.category;
    } else {
      _scope = _CampaignScope.cart;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _maxDiscountController.dispose();
    _minOrderController.dispose();
    _codeController.dispose();
    _remainingController.dispose();
    _buyController.dispose();
    _freeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _needsValue =>
      _type == PromotionType.percentDiscount ||
      _type == PromotionType.fixedDiscount;

  bool get _needsScope =>
      _type == PromotionType.percentDiscount ||
      _type == PromotionType.fixedDiscount ||
      _type == PromotionType.freeItem;

  bool get _needsBogo => _type == PromotionType.buyXGetY;

  double? _parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final minOrder = _minOrderController.text.trim().isEmpty
        ? 0.0
        : _parseAmount(_minOrderController.text);
    final value = _parseAmount(_valueController.text);
    final maxDiscount = _maxDiscountController.text.trim().isEmpty
        ? null
        : _parseAmount(_maxDiscountController.text);
    final code = _codeController.text.trim().toUpperCase();
    final remainingText = _remainingController.text.trim();
    final remaining =
        remainingText.isEmpty ? null : int.tryParse(remainingText);
    final buyQuantity = int.tryParse(_buyController.text.trim()) ?? 0;
    final freeQuantity = int.tryParse(_freeController.text.trim()) ?? 1;

    if (title.isEmpty || minOrder == null || minOrder < 0) {
      _showInvalid();
      return;
    }
    if (_needsValue) {
      if (value == null || value <= 0) {
        _showInvalid();
        return;
      }
      if (_type == PromotionType.percentDiscount && value > 100) {
        _showInvalid();
        return;
      }
    }
    if (maxDiscount != null && maxDiscount < 0) {
      _showInvalid();
      return;
    }
    if (code.isNotEmpty && _autoApply) {
      _showInvalid();
      return;
    }
    if (remainingText.isNotEmpty && (remaining == null || remaining < 0)) {
      _showInvalid();
      return;
    }
    if (_needsBogo && (buyQuantity < 1 || freeQuantity < 1)) {
      _showInvalid();
      return;
    }
    if (_type == PromotionType.freeItem && freeQuantity < 1) {
      _showInvalid();
      return;
    }
    if (_needsScope &&
        _scope == _CampaignScope.products &&
        _productIds.isEmpty) {
      _showInvalid();
      return;
    }

    final scopedProducts = _needsBogo || _scope == _CampaignScope.products;
    final scopedCategory = _needsScope && _scope == _CampaignScope.category;

    setState(() => _saving = true);
    final campaign = PromotionCampaign(
      id: widget.campaign?.id ??
          'promo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descriptionController.text.trim(),
      type: _type,
      code: code,
      value: _needsValue ? value! : 0,
      minOrderAmount: minOrder,
      maxDiscount: _type == PromotionType.percentDiscount ? maxDiscount : null,
      autoApply: code.isEmpty && _autoApply,
      isActive: _isActive,
      sortOrder: widget.campaign?.sortOrder ?? 0,
      expiresAt: _expiresAt,
      startsAt: _startsAt,
      remainingUses: remaining,
      targetCategory: scopedCategory ? _category : null,
      productIds: scopedProducts ? _productIds : const [],
      rewardProductIds: _needsBogo ? _rewardIds : const [],
      buyQuantity: _needsBogo ? buyQuantity : 0,
      freeQuantity: freeQuantity < 1 ? 1 : freeQuantity,
      firstOrderOnly: _firstOrderOnly,
    );
    await widget.onSave(campaign);
    if (mounted) setState(() => _saving = false);
  }

  void _showInvalid() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.adminPromotionInvalid.tr())),
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _startsAt : _expiresAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      final value = DateTime(
        picked.year,
        picked.month,
        picked.day,
        start ? 0 : 23,
        start ? 0 : 59,
      );
      if (start) {
        _startsAt = value;
      } else {
        _expiresAt = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final query = _searchController.text.trim().toLowerCase();
    final visibleProducts = products.where((product) {
      if (query.isEmpty) return true;
      return localizedOrRaw(product.nameKey).toLowerCase().contains(query);
    }).toList();

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
              widget.campaign == null
                  ? LocaleKeys.adminCampaignAdd.tr()
                  : LocaleKeys.adminCampaignEdit.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionTitleField.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionDescription.tr(),
                helperText: LocaleKeys.adminPromotionDescriptionHint.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<PromotionType>(
              value: _type,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionType.tr(),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final type in PromotionType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.localeKey.tr()),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 6),
            Text(
              _type.hintKey.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (_needsValue) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPromotionValue.tr(),
                  hintText: _type == PromotionType.percentDiscount
                      ? LocaleKeys.adminPromotionValuePercentHint.tr()
                      : LocaleKeys.adminPromotionValueFixedHint.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_type == PromotionType.percentDiscount) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _maxDiscountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPromotionMaxDiscount.tr(),
                  helperText: LocaleKeys.adminPromotionMaxDiscountHint.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_needsBogo) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _buyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminPromotionBuyQuantity.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _freeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminPromotionFreeQuantity.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_type == PromotionType.freeItem) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _freeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPromotionFreeQuantity.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_needsScope) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                LocaleKeys.adminPromotionScope.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<_CampaignScope>(
                value: _scope,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPromotionScope.tr(),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: _CampaignScope.cart,
                    child: Text(LocaleKeys.adminPromotionScopeCart.tr()),
                  ),
                  DropdownMenuItem(
                    value: _CampaignScope.category,
                    child: Text(LocaleKeys.adminPromotionScopeCategory.tr()),
                  ),
                  DropdownMenuItem(
                    value: _CampaignScope.products,
                    child: Text(LocaleKeys.adminPromotionScopeProducts.tr()),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _scope = value);
                },
              ),
              if (_scope == _CampaignScope.category) ...[
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.adminPromotionCategory.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final category in ProductCategory.values)
                      if (category != ProductCategory.all)
                        DropdownMenuItem(
                          value: category.name,
                          child: Text(
                            MockData.categoryKeys[category]?.tr() ??
                                category.name,
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
              ],
            ],
            if (_needsBogo ||
                (_needsScope && _scope == _CampaignScope.products)) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _needsBogo
                    ? LocaleKeys.adminPromotionBuyProducts.tr()
                    : LocaleKeys.adminPromotionProducts.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: LocaleKeys.customerSearchMenu.tr(),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProductChecks(
                products: visibleProducts,
                selectedIds: _productIds,
                onToggle: (id, selected) {
                  setState(() {
                    if (selected) {
                      if (!_productIds.contains(id)) {
                        _productIds = [..._productIds, id];
                      }
                    } else {
                      _productIds =
                          _productIds.where((item) => item != id).toList();
                    }
                  });
                },
              ),
            ],
            if (_needsBogo) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                LocaleKeys.adminPromotionRewardProducts.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                LocaleKeys.adminPromotionRewardProductsHint.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProductChecks(
                products: visibleProducts,
                selectedIds: _rewardIds,
                onToggle: (id, selected) {
                  setState(() {
                    if (selected) {
                      if (!_rewardIds.contains(id)) {
                        _rewardIds = [..._rewardIds, id];
                      }
                    } else {
                      _rewardIds =
                          _rewardIds.where((item) => item != id).toList();
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _minOrderController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionMinOrder.tr(),
                helperText: LocaleKeys.adminPromotionMinOrderHint.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionCode.tr(),
                helperText: LocaleKeys.adminPromotionCodeHint.tr(),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _remainingController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionRemaining.tr(),
                helperText: LocaleKeys.adminPromotionRemainingHint.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _pickDate(start: true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _startsAt == null
                    ? LocaleKeys.adminPromotionStarts.tr()
                    : DateFormat('d MMM yyyy', 'tr_TR').format(_startsAt!),
              ),
            ),
            if (_startsAt != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _startsAt = null),
                  child: Text(LocaleKeys.commonRemove.tr()),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _pickDate(start: false),
              icon: const Icon(Icons.event),
              label: Text(
                _expiresAt == null
                    ? LocaleKeys.adminPromotionExpires.tr()
                    : DateFormat('d MMM yyyy', 'tr_TR').format(_expiresAt!),
              ),
            ),
            if (_expiresAt != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expiresAt = null),
                  child: Text(LocaleKeys.commonRemove.tr()),
                ),
              ),
            if (_codeController.text.trim().isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(LocaleKeys.adminPromotionAutoApply.tr()),
                subtitle: Text(LocaleKeys.adminPromotionAutoApplyHint.tr()),
                value: _autoApply,
                onChanged: (value) => setState(() => _autoApply = value),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(LocaleKeys.adminPromotionFirstOrder.tr()),
              subtitle: Text(LocaleKeys.adminPromotionFirstOrderHint.tr()),
              value: _firstOrderOnly,
              onChanged: (value) => setState(() => _firstOrderOnly = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(LocaleKeys.adminPromotionActive.tr()),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
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

class _ProductChecks extends StatelessWidget {
  const _ProductChecks({
    required this.products,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Product> products;
  final List<String> selectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Text(
        LocaleKeys.adminPromotionProductsEmpty.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selectedIds.contains(product.id),
            title: Text(localizedOrRaw(product.nameKey)),
            onChanged: (value) => onToggle(product.id, value ?? false),
          );
        },
      ),
    );
  }
}
