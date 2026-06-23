import 'package:easy_localization/easy_localization.dart';



import 'package:flutter/material.dart';



import 'package:flutter_riverpod/flutter_riverpod.dart';







import '../../../../../core/localization/locale_keys.dart';



import '../../../../../core/media/app_image.dart';



import '../../../../../core/theme/app_colors.dart';



import '../../../../../core/theme/app_spacing.dart';



import '../../../../../core/utils/localized_text.dart';



import '../../../../../core/widgets/app_button.dart';



import '../../../../../shared/domain/entities/campaign_banner.dart';



import '../../../presentation/providers/campaign_provider.dart';



import '../../../presentation/widgets/admin_image_picker_field.dart';







Future<void> showAdminCampaignEditor(

  BuildContext context,

  WidgetRef ref, {

  CampaignBanner? banner,

}) async {

  final data = await showModalBottomSheet<CampaignBanner>(

    context: context,

    isScrollControlled: true,

    useSafeArea: true,

    shape: const RoundedRectangleBorder(

      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

    ),

    builder: (_) => _AdminCampaignEditorSheet(banner: banner),

  );



  if (data == null || !context.mounted) return;



  try {

    if (banner == null) {

      await ref.read(campaignBannersProvider.notifier).createBanner(

            title: data.title,

            imageUrl: data.imageUrl,

          );

    } else {

      await ref.read(campaignBannersProvider.notifier).updateBanner(data);

    }

  } catch (_) {

    if (context.mounted) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(LocaleKeys.commonError.tr())),

      );

    }

  }

}







class _AdminCampaignEditorSheet extends ConsumerStatefulWidget {

  const _AdminCampaignEditorSheet({

    required this.banner,

  });



  final CampaignBanner? banner;







  @override



  ConsumerState<_AdminCampaignEditorSheet> createState() =>



      _AdminCampaignEditorSheetState();



}







class _AdminCampaignEditorSheetState



    extends ConsumerState<_AdminCampaignEditorSheet> {



  late final TextEditingController _titleController;



  String? _imageSource;







  @override



  void initState() {



    super.initState();



    _titleController = TextEditingController(



      text: widget.banner != null ? localizedOrRaw(widget.banner!.title) : '',



    );



    _imageSource = widget.banner?.imageUrl;



  }







  @override



  void dispose() {



    _titleController.dispose();



    super.dispose();



  }







  void _save() {

    final title = _titleController.text.trim();

    Navigator.pop(

      context,

      CampaignBanner(

        id: widget.banner?.id ??

            'camp_${DateTime.now().millisecondsSinceEpoch}',

        title: title,

        imageUrl: _imageSource,

        sortOrder: widget.banner?.sortOrder ?? 0,

        isActive: widget.banner?.isActive ?? true,

      ),

    );

  }



  @override



  Widget build(BuildContext context) {



    return Padding(



      padding: EdgeInsets.only(



        left: AppSpacing.lg,



        right: AppSpacing.lg,



        top: AppSpacing.md,



        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,



      ),



      child: SingleChildScrollView(



        child: Column(



          crossAxisAlignment: CrossAxisAlignment.stretch,



          mainAxisSize: MainAxisSize.min,



          children: [



            Text(



              widget.banner == null



                  ? LocaleKeys.adminAddCampaign.tr()



                  : LocaleKeys.adminEditCampaign.tr(),



              style: Theme.of(context).textTheme.titleLarge,



            ),



            const SizedBox(height: AppSpacing.md),



            ClipRRect(



              borderRadius: BorderRadius.circular(16),



              child: SizedBox(



                height: 140,



                width: double.infinity,



                child: _imageSource != null && _imageSource!.isNotEmpty



                    ? AppImage(source: _imageSource, fit: BoxFit.cover)



                    : _bannerPlaceholder(_titleController.text),



              ),



            ),



            const SizedBox(height: AppSpacing.md),



            AdminImagePickerField(



              value: _imageSource,



              urlLabelKey: LocaleKeys.adminCampaignImageUrl,



              previewHeight: 56,



              previewWidth: 80,



              onChanged: (v) => setState(() => _imageSource = v),



            ),



            const SizedBox(height: AppSpacing.sm),



            TextField(



              controller: _titleController,



              decoration: InputDecoration(
                labelText: LocaleKeys.adminCampaignTitle.tr(),
                hintText: LocaleKeys.adminCampaignTitleHint.tr(),
              ),



              onChanged: (_) => setState(() {}),



            ),



            const SizedBox(height: AppSpacing.lg),



            AppButton(

              labelKey: LocaleKeys.commonSave,

              onPressed: _save,

            ),



          ],



        ),



      ),



    );



  }



}







Widget _bannerPlaceholder(String title) {



  return Container(



    decoration: BoxDecoration(



      gradient: LinearGradient(



        colors: [AppColors.primary, AppColors.primaryDark],



      ),



    ),



    alignment: Alignment.bottomLeft,



    padding: const EdgeInsets.all(AppSpacing.md),



    child: Text(



      title.isEmpty ? LocaleKeys.adminCampaignPreview.tr() : title,



      style: const TextStyle(



        color: AppColors.white,



        fontWeight: FontWeight.bold,



        fontSize: 18,



      ),



    ),



  );



}




