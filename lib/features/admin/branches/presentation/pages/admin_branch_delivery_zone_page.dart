import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../../../shared/domain/entities/geo_point.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../widgets/branch_delivery_zone_map.dart';

class AdminBranchDeliveryZonePage extends ConsumerStatefulWidget {
  const AdminBranchDeliveryZonePage({super.key, required this.branchId});

  final String branchId;

  @override
  ConsumerState<AdminBranchDeliveryZonePage> createState() =>
      _AdminBranchDeliveryZonePageState();
}

class _AdminBranchDeliveryZonePageState
    extends ConsumerState<AdminBranchDeliveryZonePage> {
  DeliveryZoneMode? _mode;
  double? _radiusKm;
  List<GeoPoint>? _polygon;
  var _saving = false;

  Future<void> _save(Branch branch) async {
    if (_mode == DeliveryZoneMode.polygon &&
        (_polygon == null || _polygon!.length < 3)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminZonePolygonMinPoints.tr())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(adminBranchesProvider.notifier).updateBranch(
            branch.copyWith(
              deliveryZoneMode: _mode ?? branch.deliveryZoneMode,
              deliveryRadiusKm: _radiusKm ?? branch.deliveryRadiusKm,
              deliveryPolygon: _polygon ?? branch.deliveryPolygon,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.adminZoneSaved.tr())),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(adminBranchesProvider);

    return branchesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.adminDeliveryZoneTitle.tr())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.adminDeliveryZoneTitle.tr())),
        body: Center(child: Text(LocaleKeys.commonError.tr())),
      ),
      data: (branches) {
        final branch =
            branches.where((b) => b.id == widget.branchId).firstOrNull;
        if (branch == null) {
          return Scaffold(
            appBar: AppBar(title: Text(LocaleKeys.adminDeliveryZoneTitle.tr())),
            body: Center(child: Text(LocaleKeys.commonError.tr())),
          );
        }

        _mode ??= branch.deliveryZoneMode;
        _radiusKm ??= branch.deliveryRadiusKm;
        _polygon ??= List.of(branch.deliveryPolygon);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LocaleKeys.adminDeliveryZoneTitle.tr()),
                Text(
                  branch.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: BranchDeliveryZoneMap(
                  branch: branch,
                  mode: _mode!,
                  radiusKm: _radiusKm!,
                  polygon: _polygon!,
                  onModeChanged: (mode) {
                    setState(() {
                      _mode = mode;
                      if (mode == DeliveryZoneMode.polygon &&
                          (_polygon == null || _polygon!.isEmpty)) {
                        _polygon = defaultPolygonAroundBranch(branch);
                      }
                    });
                  },
                  onRadiusChanged: (v) => setState(() => _radiusKm = v),
                  onPolygonChanged: (pts) => setState(() => _polygon = pts),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: AppButton(
                    labelKey: LocaleKeys.commonSave,
                    isLoading: _saving,
                    onPressed: _saving ? null : () => _save(branch),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
