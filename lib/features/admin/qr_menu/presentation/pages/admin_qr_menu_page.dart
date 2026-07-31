import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/qr_menu_settings.dart';
import '../../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_form_dialogs.dart';
import '../providers/qr_menu_provider.dart';
import '../widgets/qr_menu_product_editor.dart';

class AdminQrMenuPage extends ConsumerStatefulWidget {
  const AdminQrMenuPage({super.key});

  @override
  ConsumerState<AdminQrMenuPage> createState() => _AdminQrMenuPageState();
}

class _AdminQrMenuPageState extends ConsumerState<AdminQrMenuPage> {
  final _titleCtrl = TextEditingController();
  final _welcomeCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _tableCountCtrl = TextEditingController();
  var _hydrated = false;
  var _tableCountHydrated = false;
  var _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _welcomeCtrl.dispose();
    _baseUrlCtrl.dispose();
    _tableCountCtrl.dispose();
    super.dispose();
  }

  void _hydrate(QrMenuSettings s) {
    if (_hydrated) return;
    _hydrated = true;
    _titleCtrl.text = s.title;
    _welcomeCtrl.text = s.welcomeNote;
    _baseUrlCtrl.text = QrMenuSettings.normalizeBaseUrl(s.baseUrl);
  }

  void _hydrateTableCount(int count) {
    if (_tableCountHydrated) return;
    _tableCountHydrated = true;
    _tableCountCtrl.text = '$count';
  }

  Future<void> _persist(QrMenuSettings settings) async {
    await ref.read(qrMenuSettingsProvider.notifier).save(settings);
  }

  Future<void> _saveBasics(QrMenuSettings current) async {
    setState(() => _saving = true);
    try {
      await _persist(
        current.copyWith(
          title: _titleCtrl.text.trim().isEmpty
              ? current.title
              : _titleCtrl.text.trim(),
          welcomeNote: _welcomeCtrl.text.trim(),
          baseUrl: QrMenuSettings.normalizeBaseUrl(
            _baseUrlCtrl.text.trim().isEmpty
                ? current.baseUrl
                : _baseUrlCtrl.text.trim(),
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveTableCount(WaiterModeSettings? current) async {
    final n = int.tryParse(_tableCountCtrl.text.trim());
    if (n == null || n < 1 || n > WaiterModeSettings.maxTableCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminWaiterTableCountInvalid.tr())),
      );
      return;
    }
    final base = current ?? WaiterModeSettings.defaults;
    try {
      await saveWaiterModeSettings(ref, base.copyWith(tableCount: n));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    }
  }

  String _slugify(String label) {
    final map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'İ': 'i',
      'I': 'i',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };
    var s = label.trim().toLowerCase();
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty) s = 'kat_${DateTime.now().millisecondsSinceEpoch}';
    return s;
  }

  Future<void> _addCategory(QrMenuSettings settings) async {
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.adminQrMenuAddCategory.tr()),
        content: TextField(
          controller: labelCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: LocaleKeys.adminQrMenuCategoryLabel.tr(),
            hintText: 'Örn. Tostlar',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.commonAdd.tr()),
          ),
        ],
      ),
    );
    final label = labelCtrl.text.trim();
    labelCtrl.dispose();
    if (ok != true || label.isEmpty) return;

    var id = _slugify(label);
    final existing = settings.navCategories.map((e) => e.id).toSet();
    if (existing.contains(id)) {
      id = '${id}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
    final next = [
      ...settings.navCategories,
      QrNavCategory(
        id: id,
        label: label,
        sortOrder: settings.navCategories.length,
      ),
    ];
    await _persist(settings.copyWith(navCategories: next));
  }

  Future<void> _renameCategory(
    QrMenuSettings settings,
    QrNavCategory cat,
  ) async {
    final ctrl = TextEditingController(text: cat.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.adminQrMenuEditCategory.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: LocaleKeys.adminQrMenuCategoryLabel.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.commonSave.tr()),
          ),
        ],
      ),
    );
    final label = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || label.isEmpty) return;
    final next = [
      for (final c in settings.navCategories)
        if (c.id == cat.id) c.copyWith(label: label) else c,
    ];
    await _persist(settings.copyWith(navCategories: next));
  }

  Future<void> _deleteCategory(
    QrMenuSettings settings,
    QrNavCategory cat,
  ) async {
    final confirm = await showAdminDeleteConfirm(context);
    if (confirm != true) return;
    final next = settings.navCategories
        .where((c) => c.id != cat.id)
        .toList()
        .asMap()
        .entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();
    await _persist(settings.copyWith(navCategories: next));
  }

  Future<void> _moveCategory(
    QrMenuSettings settings,
    int index,
    int delta,
  ) async {
    final list = List<QrNavCategory>.from(settings.navCategories)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final j = index + delta;
    if (j < 0 || j >= list.length) return;
    final tmp = list[index];
    list[index] = list[j];
    list[j] = tmp;
    final next = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
    ];
    await _persist(settings.copyWith(navCategories: next));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qrMenuSettingsProvider);
    final waiterSettings =
        ref.watch(waiterModeSettingsProvider).valueOrNull;
    final tableCount = (waiterSettings?.tableCount ?? 24)
        .clamp(1, WaiterModeSettings.maxTableCount);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (settings) {
        _hydrate(settings);
        _hydrateTableCount(tableCount);
        final cats = List<QrNavCategory>.from(settings.navCategories)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final products =
            ref.watch(adminProductsProvider).valueOrNull ?? [];
        final extras =
            ref.watch(adminCatalogExtrasProvider).valueOrNull ?? [];
        final hidden = settings.hiddenProductIds.toSet();
        final featured = settings.featuredProductIds.toSet();

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              LocaleKeys.adminQrMenuSubtitle.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(LocaleKeys.adminQrMenuEnabled.tr()),
              value: settings.enabled,
              onChanged: (v) => _persist(settings.copyWith(enabled: v)),
            ),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminQrMenuTitle.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _welcomeCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminQrMenuWelcome.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _baseUrlCtrl,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminQrMenuBaseUrl.tr(),
                hintText: QrMenuSettings.defaultBaseUrl,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveBasics(settings),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(LocaleKeys.commonSave.tr()),
            ),

            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocaleKeys.adminQrMenuCategories.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addCategory(settings),
                  icon: const Icon(Icons.add),
                  label: Text(LocaleKeys.commonAdd.tr()),
                ),
              ],
            ),
            Text(
              LocaleKeys.adminQrMenuCategoriesHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (cats.isEmpty)
              Text(LocaleKeys.adminQrMenuCategoriesEmpty.tr())
            else
              ...cats.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ListTile(
                    title: Text(cat.label),
                    subtitle: Text(cat.id),
                    leading: Switch(
                      value: cat.enabled,
                      onChanged: (v) {
                        final next = [
                          for (final c in settings.navCategories)
                            if (c.id == cat.id) c.copyWith(enabled: v) else c,
                        ];
                        _persist(settings.copyWith(navCategories: next));
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Yukarı',
                          onPressed: () => _moveCategory(settings, i, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Aşağı',
                          onPressed: () => _moveCategory(settings, i, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          onPressed: () => _renameCategory(settings, cat),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteCategory(settings, cat),
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocaleKeys.adminQrMenuProducts.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: cats.isEmpty
                      ? null
                      : () => showQrMenuProductEditor(
                            context,
                            ref,
                            navCategories: cats,
                          ),
                  icon: const Icon(Icons.add),
                  label: Text(LocaleKeys.commonAdd.tr()),
                ),
              ],
            ),
            Text(
              LocaleKeys.adminQrMenuProductsManageHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (products.isEmpty)
              Text(LocaleKeys.waiterAddonsEmpty.tr())
            else
              ...products.map((p) {
                final catLabel = cats
                        .where((c) => c.id == p.effectiveQrNavCategoryId)
                        .map((c) => c.label)
                        .firstOrNull ??
                    p.effectiveQrNavCategoryId;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ListTile(
                    title: Text(localizedOrRaw(p.nameKey)),
                    subtitle: Text(
                      '${catLabel} · ${p.price.toStringAsFixed(0)} TL'
                      '${hidden.contains(p.id) ? ' · gizli' : ''}'
                      '${featured.contains(p.id) ? ' · öne çıkan' : ''}',
                    ),
                    onTap: () => showQrMenuProductEditor(
                      context,
                      ref,
                      product: p,
                      navCategories: cats,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: LocaleKeys.adminQrMenuFeatured.tr(),
                          icon: Icon(
                            featured.contains(p.id)
                                ? Icons.star
                                : Icons.star_border,
                            color: featured.contains(p.id)
                                ? Colors.amber.shade700
                                : null,
                          ),
                          onPressed: () {
                            final next =
                                List<String>.from(settings.featuredProductIds);
                            if (featured.contains(p.id)) {
                              next.remove(p.id);
                            } else {
                              next.add(p.id);
                            }
                            _persist(
                              settings.copyWith(featuredProductIds: next),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: hidden.contains(p.id)
                              ? LocaleKeys.adminQrMenuProductVisible.tr()
                              : LocaleKeys.adminQrMenuProductHidden.tr(),
                          icon: Icon(
                            hidden.contains(p.id)
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            final next =
                                List<String>.from(settings.hiddenProductIds);
                            if (hidden.contains(p.id)) {
                              next.remove(p.id);
                            } else {
                              next.add(p.id);
                            }
                            _persist(
                              settings.copyWith(hiddenProductIds: next),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.error,
                          onPressed: () async {
                            final confirm =
                                await showAdminDeleteConfirm(context);
                            if (confirm != true) return;
                            await ref
                                .read(adminProductsProvider.notifier)
                                .deleteProduct(p.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),

            if (extras.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                LocaleKeys.adminQrMenuExtrasNote.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            Text(
              LocaleKeys.adminQrMenuTableCodes.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              LocaleKeys.adminQrMenuTableCodesHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _tableCountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminQrMenuTableCount.tr(),
                      hintText: LocaleKeys.adminWaiterTableCountHint.tr(),
                      helperText: LocaleKeys.adminQrMenuTableCountHelper.tr(
                        namedArgs: {
                          'max': '${WaiterModeSettings.maxTableCount}',
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonal(
                    onPressed: () => _saveTableCount(waiterSettings),
                    child: Text(LocaleKeys.commonSave.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...List.generate(tableCount, (i) {
              final n = i + 1;
              final url = settings.tableUrl(n);
              final qrImg =
                  'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(url)}';
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          qrImg,
                          width: 72,
                          height: 72,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.qr_code_2, size: 48),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocaleKeys.dineInTableLabel.tr(
                                namedArgs: {'table': '$n'},
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: url),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocaleKeys.commonCopied.tr(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(LocaleKeys.commonCopy.tr()),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: Text(LocaleKeys.commonOpen.tr()),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
