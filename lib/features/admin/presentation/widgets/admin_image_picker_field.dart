import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/media/app_image.dart';
import '../../../../core/media/media_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/admin_media_provider.dart';
import '../../../../shared/domain/entities/media_asset.dart';

/// Ürün, extra ve kampanya formlarında kullanılan ortak görsel seçici.
class AdminImagePickerField extends ConsumerWidget {
  const AdminImagePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.urlLabelKey = LocaleKeys.adminProductImageUrl,
    this.previewHeight = 72,
    this.previewWidth = 72,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String urlLabelKey;
  final double previewHeight;
  final double previewWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(adminMediaSourcesProvider);
    final selected = value?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.adminImagePickHint.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: previewHeight + 8,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _UploadTile(
                  size: previewHeight,
                  onTap: () async {
                    final path = await MediaStorageService.pickAndSaveImage();
                    if (path == null) return;
                    await ref.read(adminMediaProvider.notifier).addSource(path);
                    onChanged(path);
                  },
                );
              }
              final source = presets[index - 1];
              final isSelected = selected == source;
              return GestureDetector(
                onTap: () => onChanged(source),
                child: Container(
                  width: previewWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppImage(
                    source: source,
                    width: previewWidth,
                    height: previewHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          initialValue: selected,
          decoration: InputDecoration(
            labelText: urlLabelKey.tr(),
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              tooltip: LocaleKeys.adminImageUpload.tr(),
              icon: const Icon(Icons.upload_outlined),
              onPressed: () async {
                final path = await MediaStorageService.pickAndSaveImage();
                if (path == null) return;
                await ref.read(adminMediaProvider.notifier).addSource(path);
                onChanged(path);
              },
            ),
          ),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
        ),
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, color: AppColors.primary, size: size * 0.28),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.adminImageUpload.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Görsel kütüphanesine URL ekleme diyaloğu.
Future<void> showAdminMediaAddUrlDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(LocaleKeys.adminMediaAddUrl.tr()),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: LocaleKeys.adminProductImageUrl.tr(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(LocaleKeys.commonCancel.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(LocaleKeys.commonAdd.tr()),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null && result.isNotEmpty) {
    await ref.read(adminMediaProvider.notifier).addUrl(result);
  }
}

/// Yönetici görsel kütüphanesi sekmesi.
class AdminMediaLibraryTab extends ConsumerWidget {
  const AdminMediaLibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(adminMediaProvider);

    return mediaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (assets) {
        if (assets.isEmpty) {
          return Center(child: Text(LocaleKeys.adminMediaEmpty.tr()));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return _MediaGridTile(
              asset: asset,
              onDelete: () =>
                  ref.read(adminMediaProvider.notifier).remove(asset.id),
            );
          },
        );
      },
    );
  }

  static Future<void> uploadNew(WidgetRef ref) async {
    await ref.read(adminMediaProvider.notifier).addFromPicker();
  }
}

class _MediaGridTile extends StatelessWidget {
  const _MediaGridTile({
    required this.asset,
    required this.onDelete,
  });

  final MediaAsset asset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AppImage(
            source: asset.source,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
        if (asset.kind == MediaAssetKind.local)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                LocaleKeys.adminMediaUploaded.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
      ],
    );
  }
}
