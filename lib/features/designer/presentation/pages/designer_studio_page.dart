import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../data/gemini_design_service.dart';
import '../../data/gemini_key_resolver.dart';
import '../../domain/design_models.dart';

class DesignerStudioPage extends ConsumerStatefulWidget {
  const DesignerStudioPage({super.key});

  @override
  ConsumerState<DesignerStudioPage> createState() => _DesignerStudioPageState();
}

class _DesignerStudioPageState extends ConsumerState<DesignerStudioPage> {
  final _briefController = TextEditingController();
  final _headlineController = TextEditingController();

  DesignFormat _format = DesignFormat.post;
  var _briefMixed = true;
  Product? _product;
  Uint8List? _resultBytes;
  Uint8List? _userImageBytes;
  String _userImageMime = 'image/jpeg';
  var _busy = false;
  String? _status;
  String? _lastError;

  @override
  void dispose() {
    _briefController.dispose();
    _headlineController.dispose();
    super.dispose();
  }

  String _productLabel(Product p) => localizedOrRaw(p.nameKey);

  String get _subjectName {
    if (_product != null) return _productLabel(_product!);
    return 'Tost-u Şahane';
  }

  Future<void> _pickUserImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final mime = switch (picked.mimeType?.toLowerCase()) {
        'image/png' => 'image/png',
        'image/webp' => 'image/webp',
        _ => picked.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg',
      };
      setState(() {
        _userImageBytes = bytes;
        _userImageMime = mime;
        _lastError = null;
      });
    } catch (e) {
      setState(() => _lastError = e.toString());
    }
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _lastError = null;
      _busy = true;
      _status = LocaleKeys.designerGenerating.tr();
    });

    try {
      final key = await ref.read(geminiKeyResolverProvider).resolve();
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        throw GeminiDesignException(LocaleKeys.designerMissingKey.tr());
      }
      if (!_briefMixed && _briefController.text.trim().isEmpty) {
        throw GeminiDesignException(LocaleKeys.designerBriefRequired.tr());
      }

      final headline = _headlineController.text.trim().isEmpty
          ? _subjectName.toUpperCase()
          : _headlineController.text.trim();

      final bytes =
          await ref.read(geminiDesignServiceProvider).generateCreativeImage(
                format: _format,
                subjectName: _subjectName,
                headline: headline,
                cta: DesignerBrand.defaultCta,
                userBrief: _briefMixed ? null : _briefController.text.trim(),
                mixedStyle: _briefMixed,
                productImageUrl: _product?.imageUrl,
                referenceImageBytes: _userImageBytes,
                referenceMimeType: _userImageMime,
              );

      if (!mounted) return;
      setState(() {
        _resultBytes = bytes;
        _busy = false;
        _status = null;
        _lastError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is GeminiDesignException ? e.message : e.toString();
      setState(() {
        _busy = false;
        _status = null;
        _lastError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _download() async {
    final bytes = _resultBytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.designerNoImage.tr())),
      );
      return;
    }
    final name =
        'tostu_${_format == DesignFormat.story ? 'story' : 'post'}_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(bytes, mimeType: 'image/png', name: name),
            ],
            fileNameOverrides: [name],
          ),
        );
      } else {
        final downloads = await getDownloadsDirectory();
        final docs = await getApplicationDocumentsDirectory();
        final path = '${downloads?.path ?? docs.path}/$name';
        await XFile.fromData(bytes, mimeType: 'image/png', name: name)
            .saveTo(path);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocaleKeys.designerExportOk.tr()}: $name'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocaleKeys.designerDownloadFailed.tr()}: $e'),
        ),
      );
    }
  }

  Future<void> _share() async {
    final bytes = _resultBytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.designerNoImage.tr())),
      );
      return;
    }
    final name =
        'tostu_${_format == DesignFormat.story ? 'story' : 'post'}_${DateTime.now().millisecondsSinceEpoch}.png';
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: name),
          ],
          fileNameOverrides: [name],
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';
    await XFile.fromData(bytes, mimeType: 'image/png', name: name).saveTo(path);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Tost-u Şahane'),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go(RoutePaths.authLogin);
  }

  @override
  Widget build(BuildContext context) {
    final products = (ref.watch(productsProvider).value ?? [])
        .where((p) => p.isAvailable)
        .toList();
    final geminiKeyAsync = ref.watch(geminiApiKeyProvider);
    final hasKey = geminiKeyAsync.maybeWhen(
      data: (k) => k != null && k.isNotEmpty,
      orElse: () => false,
    );
    final keyLoading = geminiKeyAsync.isLoading;
    final hasResult = _resultBytes != null && _resultBytes!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EC),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onLogout: _logout,
              hasKey: hasKey,
              keyLoading: keyLoading,
            ),
            if (_busy)
              const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primary,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (!hasKey && !keyLoading) ...[
                    _AlertBox(
                      color: const Color(0xFFFFF4E5),
                      textColor: const Color(0xFF9A5B00),
                      text: LocaleKeys.designerMissingKey.tr(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_lastError != null) ...[
                    _AlertBox(
                      color: const Color(0xFFFFEBEE),
                      textColor: const Color(0xFFB71C1C),
                      text: _lastError!,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 1) Format
                  _SectionTitle('1. ${LocaleKeys.designerSizeLabel.tr()}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceCard(
                          selected: _format == DesignFormat.post,
                          title: LocaleKeys.designerFormatPost.tr(),
                          subtitle: 'Instagram / Facebook',
                          icon: Icons.crop_square_rounded,
                          onTap: _busy
                              ? null
                              : () => setState(() => _format = DesignFormat.post),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceCard(
                          selected: _format == DesignFormat.story,
                          title: LocaleKeys.designerFormatStory.tr(),
                          subtitle: 'Story / Reels',
                          icon: Icons.crop_portrait_rounded,
                          onTap: _busy
                              ? null
                              : () =>
                                  setState(() => _format = DesignFormat.story),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2) Brief
                  _SectionTitle('2. ${LocaleKeys.designerBriefLabel.tr()}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ChipChoice(
                          selected: _briefMixed,
                          label: LocaleKeys.designerBriefMixed.tr(),
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                    _briefMixed = true;
                                    _lastError = null;
                                  }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ChipChoice(
                          selected: !_briefMixed,
                          label: LocaleKeys.designerBriefCustom.tr(),
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                    _briefMixed = false;
                                    _lastError = null;
                                  }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _briefController,
                    enabled: !_busy && !_briefMixed,
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: _briefMixed
                          ? 'Karışık seçili: Gemini örnek kreatiflere benzer rastgele üretir. Kendi metnini yazmak için “Kendi isteğim”i seç.'
                          : LocaleKeys.designerBriefHint.tr(),
                      filled: true,
                      fillColor: _briefMixed
                          ? const Color(0xFFEDE7E1)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD9CFC6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD9CFC6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: DesignerBrand.brandNavy,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3) Optional extras
                  _SectionTitle('3. Opsiyonel'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _headlineController,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.designerHeadline.tr(),
                      hintText: 'Boş bırakılırsa ürün/marka adı kullanılır',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use — controlled selection needs value
                    value: _product?.id,
                    decoration: InputDecoration(
                      labelText:
                          '${LocaleKeys.designerProduct.tr()} (opsiyonel)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Ürün seçme'),
                      ),
                      ...products.map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(productLabelSafe(p)),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) {
                            if (id == null) {
                              setState(() => _product = null);
                              return;
                            }
                            for (final p in products) {
                              if (p.id == id) {
                                setState(() {
                                  _product = p;
                                  if (_headlineController.text.trim().isEmpty) {
                                    _headlineController.text =
                                        _productLabel(p).toUpperCase();
                                  }
                                });
                                return;
                              }
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickUserImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _userImageBytes == null
                          ? LocaleKeys.designerUploadImage.tr()
                          : LocaleKeys.designerChangeImage.tr(),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_userImageBytes != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _userImageBytes!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _userImageBytes = null;
                                    _userImageMime = 'image/jpeg';
                                  }),
                          child: Text(LocaleKeys.designerClearImage.tr()),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Preview / result
                  _SectionTitle(
                    hasResult
                        ? 'Sonuç'
                        : LocaleKeys.designerExamples.tr(),
                  ),
                  const SizedBox(height: 8),
                  _PreviewCard(
                    format: _format,
                    busy: _busy,
                    status: _status,
                    resultBytes: _resultBytes,
                  ),
                  if (hasResult) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _download,
                            icon: const Icon(Icons.download),
                            label: Text(LocaleKeys.designerDownload.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _busy ? null : _share,
                          icon: const Icon(Icons.share_outlined),
                          tooltip: LocaleKeys.designerShare.tr(),
                        ),
                        IconButton.outlined(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _resultBytes = null;
                                    _lastError = null;
                                  }),
                          icon: const Icon(Icons.close),
                          tooltip: 'Sonucu temizle',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Sticky generate bar — always visible
            Material(
              elevation: 8,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          hasResult ? Icons.refresh : Icons.auto_awesome,
                        ),
                  label: Text(
                    _busy
                        ? LocaleKeys.designerGenerating.tr()
                        : hasResult
                            ? LocaleKeys.designerRegenerate.tr()
                            : LocaleKeys.designerGenerateImage.tr().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignerBrand.brandNavy,
                    disabledBackgroundColor:
                        DesignerBrand.brandNavy.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String productLabelSafe(Product p) => _productLabel(p);
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onLogout,
    required this.hasKey,
    required this.keyLoading,
  });

  final VoidCallback onLogout;
  final bool hasKey;
  final bool keyLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            Image.asset(DesignerBrand.mascotAsset, width: 40, height: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.designerStudioTitle.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    keyLoading
                        ? 'Gemini kontrol ediliyor…'
                        : hasKey
                            ? 'Gemini hazır'
                            : 'Anahtar yok — yeniden derle',
                    style: TextStyle(
                      color: hasKey
                          ? const Color(0xFF1B7A3D)
                          : Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onLogout,
              child: Text(LocaleKeys.designerLogout.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1214),
      ),
    );
  }
}

class _AlertBox extends StatelessWidget {
  const _AlertBox({
    required this.color,
    required this.textColor,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DesignerBrand.brandNavy : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? DesignerBrand.brandNavy
                  : const Color(0xFFD9CFC6),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? Colors.white : DesignerBrand.brandNavy,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF1A1214),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? Colors.white70
                      : const Color(0xFF6B5E62),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipChoice extends StatelessWidget {
  const _ChipChoice({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DesignerBrand.brandPrimary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? DesignerBrand.brandPrimary
                  : const Color(0xFFD9CFC6),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF1A1214),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.format,
    required this.busy,
    required this.status,
    required this.resultBytes,
  });

  final DesignFormat format;
  final bool busy;
  final String? status;
  final Uint8List? resultBytes;

  @override
  Widget build(BuildContext context) {
    final hasResult = resultBytes != null && resultBytes!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9CFC6)),
      ),
      child: hasResult
          ? Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: format == DesignFormat.story ? 420 : 360,
                  ),
                  child: AspectRatio(
                    aspectRatio: format.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(resultBytes!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      DesignerBrand.mascotAsset,
                      width: 44,
                      height: 44,
                    ),
                    const SizedBox(width: 10),
                    SvgPicture.asset(
                      DesignerBrand.wordmarkAsset,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        DesignerBrand.brandNavy,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (busy) ...[
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 10),
                  Text(
                    status ?? LocaleKeys.designerGenerating.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ] else ...[
                  const Text(
                    'Alttaki ÜRET butonuna bas.\nBoyut + istek seçtikten sonra Gemini görsel üretir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B5E62),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: DesignerBrand.exampleAssets.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            DesignerBrand.exampleAssets[i],
                            width: 88,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
