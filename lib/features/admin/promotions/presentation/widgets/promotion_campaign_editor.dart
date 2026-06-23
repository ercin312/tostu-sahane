import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';

Future<void> showPromotionCampaignEditor(
  BuildContext context,
  WidgetRef ref, {
  PromotionCampaign? campaign,
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
          await savePromotionCampaign(ref, data);
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

class _PromotionCampaignEditorSheet extends StatefulWidget {
  const _PromotionCampaignEditorSheet({
    required this.campaign,
    required this.onSave,
  });

  final PromotionCampaign? campaign;
  final Future<void> Function(PromotionCampaign campaign) onSave;

  @override
  State<_PromotionCampaignEditorSheet> createState() =>
      _PromotionCampaignEditorSheetState();
}

class _PromotionCampaignEditorSheetState
    extends State<_PromotionCampaignEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _valueController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _codeController;

  late PromotionType _type;
  late bool _autoApply;
  late bool _isActive;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    _titleController = TextEditingController(text: campaign?.title ?? '');
    _valueController = TextEditingController(
      text: campaign?.value == 0 ? '' : '${campaign?.value ?? ''}',
    );
    _minOrderController = TextEditingController(
      text: campaign?.minOrderAmount == 0
          ? ''
          : '${campaign?.minOrderAmount ?? ''}',
    );
    _codeController = TextEditingController(text: campaign?.code ?? '');
    _type = campaign?.type ?? PromotionType.percentDiscount;
    _autoApply = campaign?.autoApply ?? false;
    _isActive = campaign?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    _minOrderController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final minOrder = double.tryParse(
      _minOrderController.text.trim().replaceAll(',', '.'),
    );
    final value = double.tryParse(
      _valueController.text.trim().replaceAll(',', '.'),
    );
    final code = _codeController.text.trim().toUpperCase();

    if (title.isEmpty || minOrder == null || minOrder < 0) {
      _showInvalid();
      return;
    }
    if (_type != PromotionType.freeDrinks &&
        (value == null || value <= 0)) {
      _showInvalid();
      return;
    }
    if (code.isNotEmpty && _autoApply) {
      _showInvalid();
      return;
    }

    setState(() => _saving = true);
    final campaign = PromotionCampaign(
      id: widget.campaign?.id ??
          'promo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: _type,
      code: code,
      value: _type == PromotionType.freeDrinks ? 0 : value!,
      minOrderAmount: minOrder,
      autoApply: code.isEmpty && _autoApply,
      isActive: _isActive,
      sortOrder: widget.campaign?.sortOrder ?? 0,
    );
    await widget.onSave(campaign);
    if (mounted) setState(() => _saving = false);
  }

  void _showInvalid() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.adminPromotionInvalid.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showValue = _type != PromotionType.freeDrinks;

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
            DropdownButtonFormField<PromotionType>(
              value: _type,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionType.tr(),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: PromotionType.percentDiscount,
                  child: Text(LocaleKeys.adminPromotionTypePercent.tr()),
                ),
                DropdownMenuItem(
                  value: PromotionType.fixedDiscount,
                  child: Text(LocaleKeys.adminPromotionTypeFixed.tr()),
                ),
                DropdownMenuItem(
                  value: PromotionType.freeDrinks,
                  child: Text(LocaleKeys.adminPromotionTypeFreeDrinks.tr()),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            if (showValue) ...[
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
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _minOrderController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminPromotionMinOrder.tr(),
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
