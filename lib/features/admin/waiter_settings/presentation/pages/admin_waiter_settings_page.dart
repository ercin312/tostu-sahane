import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/print_routing_settings.dart';
import '../../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../../shared/domain/entities/waiter_preparation_option.dart';
import '../../../../../shared/presentation/providers/print_routing_settings_provider.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../widgets/admin_print_routing_panel.dart';
import '../widgets/admin_waiter_tabs.dart';
import '../widgets/admin_waiter_preparation_tab.dart';

class AdminWaiterSettingsPage extends ConsumerStatefulWidget {
  const AdminWaiterSettingsPage({super.key});

  @override
  ConsumerState<AdminWaiterSettingsPage> createState() =>
      _AdminWaiterSettingsPageState();
}

class _AdminWaiterSettingsPageState extends ConsumerState<AdminWaiterSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _tableCountController = TextEditingController();
  final _posHostController = TextEditingController();
  final _posPortController = TextEditingController();
  final _posSerialController = TextEditingController();
  final _posSalePathController = TextEditingController();
  var _customerSahandaEnabled = true;
  var _posEnabled = false;
  var _saving = false;
  var _printRouting = PrintRoutingSettings.defaults;
  var _preparationOptions = <WaiterPreparationOption>[];
  var _productDisplayOrder = <String>[];
  var _catalogExtraDisplayOrder = <String>[];
  var _loaded = false;
  var _routingLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tableCountController.dispose();
    _posHostController.dispose();
    _posPortController.dispose();
    _posSerialController.dispose();
    _posSalePathController.dispose();
    super.dispose();
  }

  void _ensureLoaded(WaiterModeSettings settings) {
    if (_loaded) return;
    _loaded = true;
    _tableCountController.text = '${settings.tableCount}';
    _customerSahandaEnabled = settings.customerSahandaEnabled;
    _posEnabled = settings.posEnabled;
    _posHostController.text = settings.posHost;
    _posPortController.text = '${settings.posPort}';
    _posSerialController.text = settings.posSerialNumber;
    _posSalePathController.text = settings.posSalePath;
    _preparationOptions = List.from(settings.preparationOptions);
    _productDisplayOrder = List.from(settings.productDisplayOrder);
    _catalogExtraDisplayOrder = List.from(settings.catalogExtraDisplayOrder);
  }

  void _ensureRoutingLoaded(PrintRoutingSettings settings) {
    if (_routingLoaded) return;
    _routingLoaded = true;
    _printRouting = settings;
  }

  Future<void> _save() async {
    final tableCount = int.tryParse(_tableCountController.text.trim());
    if (tableCount == null ||
        tableCount < 1 ||
        tableCount > WaiterModeSettings.maxTableCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminWaiterTableCountInvalid.tr())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final posPort = int.tryParse(_posPortController.text.trim()) ?? 4568;
      await saveWaiterModeSettings(
        ref,
        WaiterModeSettings(
          tableCount: tableCount,
          customerSahandaEnabled: _customerSahandaEnabled,
          printKitchenReceiptOnWaiterOrder:
              _printRouting.dineInAtKitchen || _printRouting.dineInAtCashier,
          posEnabled: _posEnabled,
          posHost: _posHostController.text.trim(),
          posPort: posPort.clamp(1, 65535),
          posSerialNumber: _posSerialController.text.trim(),
          posSalePath: _posSalePathController.text.trim().isEmpty
              ? '/Payment/CardPayment'
              : _posSalePathController.text.trim(),
          productPrices: const {},
          catalogExtraPrices: const {},
          preparationOptions: _preparationOptions,
          productDisplayOrder: _productDisplayOrder,
          catalogExtraDisplayOrder: _catalogExtraDisplayOrder,
        ),
      );
      await savePrintRoutingSettings(ref, _printRouting);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminWaiterSettingsSaved.tr())),
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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(waiterModeSettingsProvider);
    final routingAsync = ref.watch(printRoutingSettingsProvider);
    final usersAsync = ref.watch(adminUsersProvider);
    final waiterCount = usersAsync.value
            ?.where((u) => u.role == 'waiter' && u.isActive)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminWaiterSettingsTitle.tr()),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(LocaleKeys.commonSave.tr()),
          ),
          const RoleLogoutAction(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: LocaleKeys.adminWaiterTabGeneral.tr()),
            Tab(text: LocaleKeys.adminWaiterTabMenu.tr()),
            Tab(text: LocaleKeys.adminWaiterTabExtras.tr()),
            Tab(text: LocaleKeys.adminWaiterTabPrep.tr()),
            Tab(text: LocaleKeys.adminWaiterTabSort.tr()),
          ],
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (settings) {
          _ensureLoaded(settings);
          routingAsync.whenData(_ensureRoutingLoaded);
          return TabBarView(
            controller: _tabController,
            children: [
              ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    LocaleKeys.adminWaiterSettingsSubtitle.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocaleKeys.adminWaiterTableCount.tr(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _tableCountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText:
                                  LocaleKeys.adminWaiterTableCountHint.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: SwitchListTile(
                      title: Text(LocaleKeys.adminCustomerSahandaEnabled.tr()),
                      subtitle: Text(
                        LocaleKeys.adminCustomerSahandaEnabledHint.tr(),
                      ),
                      value: _customerSahandaEnabled,
                      onChanged: (value) =>
                          setState(() => _customerSahandaEnabled = value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AdminPrintRoutingPanel(
                    settings: _printRouting,
                    onChanged: (value) =>
                        setState(() => _printRouting = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocaleKeys.adminPosSettingsTitle.tr(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(LocaleKeys.adminPosEnabled.tr()),
                            subtitle: Text(LocaleKeys.adminPosEnabledHint.tr()),
                            value: _posEnabled,
                            onChanged: (value) =>
                                setState(() => _posEnabled = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _posHostController,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.adminPosHost.tr(),
                              hintText: LocaleKeys.adminPosHostHint.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _posPortController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.adminPosPort.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _posSerialController,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.adminPosSerial.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _posSalePathController,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.adminPosSalePath.tr(),
                              hintText: LocaleKeys.adminPosSalePathHint.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: Text(LocaleKeys.adminWaiterUsersCardTitle.tr()),
                      subtitle: Text(
                        LocaleKeys.adminWaiterUsersCardSubtitle.tr(
                          namedArgs: {'count': '$waiterCount'},
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(RoutePaths.adminUsers),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
              const AdminWaiterMenuTab(),
              const AdminWaiterExtrasTab(),
              AdminWaiterPreparationTab(
                options: _preparationOptions,
                onChanged: (value) =>
                    setState(() => _preparationOptions = value),
              ),
              AdminWaiterSortTab(
                productOrder: _productDisplayOrder,
                extraOrder: _catalogExtraDisplayOrder,
                onProductOrderChanged: (value) =>
                    setState(() => _productDisplayOrder = value),
                onExtraOrderChanged: (value) =>
                    setState(() => _catalogExtraDisplayOrder = value),
              ),
            ],
          );
        },
      ),
    );
  }
}
