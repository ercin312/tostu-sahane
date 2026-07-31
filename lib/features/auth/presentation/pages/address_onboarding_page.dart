import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../customer/profile/presentation/pages/address_map_picker_page.dart';
import '../../../customer/profile/presentation/providers/address_provider.dart';
import '../providers/auth_provider.dart';

class AddressOnboardingPage extends ConsumerStatefulWidget {
  const AddressOnboardingPage({super.key});

  @override
  ConsumerState<AddressOnboardingPage> createState() =>
      _AddressOnboardingPageState();
}

class _AddressOnboardingPageState extends ConsumerState<AddressOnboardingPage> {
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  double? _lat;
  double? _lng;
  var _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressMapPickerPage(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _addressController.text =
          (result['address'] as String?) ?? _addressController.text;
      _lat = (result['latitude'] as num?)?.toDouble();
      _lng = (result['longitude'] as num?)?.toDouble();
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim().isEmpty
        ? LocaleKeys.addressTitleHome.tr()
        : _titleController.text.trim();
    final fullAddress = _addressController.text.trim();
    if (fullAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.addressFullLabel.tr())),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authAddressPinRequired.tr())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(addressProvider.notifier).addAddress(
            title: title,
            fullAddress: fullAddress,
            setDefault: true,
            latitude: _lat,
            longitude: _lng,
          );
      await ref.read(authProvider.notifier).clearNeedsAddressOnboarding();
      if (!mounted) return;
      context.go(RoutePaths.customerHome);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.authAddressOnboardingTitle.tr()),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.authAddressOnboardingSubtitle.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.addressTitleLabel.tr(),
                  hintText: LocaleKeys.addressTitleHome.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: LocaleKeys.addressFullLabel.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickOnMap,
                icon: const Icon(Icons.location_on_outlined),
                label: Text(
                  _lat == null
                      ? LocaleKeys.authPickLocationOnMap.tr()
                      : LocaleKeys.authLocationSelected.tr(),
                ),
              ),
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                labelKey: LocaleKeys.authSaveDefaultAddress,
                onPressed: _saving ? null : _save,
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
