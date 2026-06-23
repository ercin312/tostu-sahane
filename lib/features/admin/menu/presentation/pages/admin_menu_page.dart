import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../../core/localization/locale_keys.dart';

import '../../../../../core/media/app_image.dart';

import '../../../../../core/theme/app_colors.dart';

import '../../../../../core/theme/app_spacing.dart';

import '../../../../../core/utils/localized_text.dart';

import '../../../../../core/widgets/product_thumbnail.dart';

import '../../../../../core/widgets/role_logout_action.dart';

import '../../../../../shared/domain/entities/campaign_banner.dart';

import '../../../../../shared/domain/entities/product.dart';

import '../../../presentation/providers/admin_provider.dart';

import '../../../presentation/providers/campaign_provider.dart';

import '../../../presentation/widgets/admin_form_dialogs.dart';

import '../../../presentation/widgets/admin_image_picker_field.dart';

import '../widgets/admin_catalog_extras_tab.dart';
import '../widgets/admin_campaign_editor.dart';

import '../widgets/admin_product_editor_sheet.dart';
import '../widgets/admin_product_reviews_panel.dart';



class AdminMenuPage extends ConsumerStatefulWidget {

  const AdminMenuPage({super.key});



  @override

  ConsumerState<AdminMenuPage> createState() => _AdminMenuPageState();

}



class _AdminMenuPageState extends ConsumerState<AdminMenuPage>

    with SingleTickerProviderStateMixin {

  late final TabController _tabController;



  @override

  void initState() {

    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() => setState(() {}));

  }



  @override

  void dispose() {

    _tabController.dispose();

    super.dispose();

  }



  void _onFabPressed() {

    final index = _tabController.index;

    if (index == 0) {

      showAdminProductEditor(context, ref);

    } else if (index == 1) {

      showAdminCatalogExtraEditor(context, ref);

    } else if (index == 2) {

      showAdminCampaignEditor(context, ref);

    } else {

      _showMediaFabMenu();

    }

  }



  Future<void> _showMediaFabMenu() async {

    final action = await showModalBottomSheet<String>(

      context: context,

      builder: (ctx) => SafeArea(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            ListTile(

              leading: const Icon(Icons.upload_file),

              title: Text(LocaleKeys.adminImageUpload.tr()),

              onTap: () => Navigator.pop(ctx, 'upload'),

            ),

            ListTile(

              leading: const Icon(Icons.link),

              title: Text(LocaleKeys.adminMediaAddUrl.tr()),

              onTap: () => Navigator.pop(ctx, 'url'),

            ),

          ],

        ),

      ),

    );

    if (!mounted || action == null) return;

    if (action == 'upload') {

      await AdminMediaLibraryTab.uploadNew(ref);

    } else if (action == 'url') {

      await showAdminMediaAddUrlDialog(context, ref);

    }

  }



  String get _fabLabel {

    return switch (_tabController.index) {

      0 => LocaleKeys.adminAddProduct.tr(),

      1 => LocaleKeys.adminAddExtra.tr(),

      2 => LocaleKeys.adminAddCampaign.tr(),

      _ => LocaleKeys.adminMediaAdd.tr(),

    };

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: Text(LocaleKeys.adminMenuTitle.tr()),

        actions: const [RoleLogoutAction()],

        bottom: TabBar(

          controller: _tabController,

          tabs: [

            Tab(

              icon: const Icon(Icons.restaurant_menu_outlined),

              text: LocaleKeys.adminTabProducts.tr(),

            ),

            Tab(

              icon: const Icon(Icons.add_shopping_cart_outlined),

              text: LocaleKeys.adminTabExtras.tr(),

            ),

            Tab(

              icon: const Icon(Icons.campaign_outlined),

              text: LocaleKeys.adminTabCampaigns.tr(),

            ),

            Tab(

              icon: const Icon(Icons.photo_library_outlined),

              text: LocaleKeys.adminTabMedia.tr(),

            ),

          ],

        ),

      ),

      body: TabBarView(

        controller: _tabController,

        children: const [

          _ProductsTab(),

          AdminCatalogExtrasTab(),

          _CampaignsTab(),

          AdminMediaLibraryTab(),

        ],

      ),

      floatingActionButton: FloatingActionButton.extended(

        onPressed: _onFabPressed,

        icon: const Icon(Icons.add),

        label: Text(_fabLabel),

      ),

    );

  }

}



class _ProductsTab extends ConsumerWidget {

  const _ProductsTab();



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final productsAsync = ref.watch(adminProductsProvider);



    return productsAsync.when(

      loading: () => const Center(child: CircularProgressIndicator()),

      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),

      data: (products) {

        if (products.isEmpty) {

          return Center(child: Text(LocaleKeys.adminNoProducts.tr()));

        }

        return Column(
          children: [
            const AdminProductReviewsPanel(itemLimit: 5),
            Expanded(
              child: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(

            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,

            mainAxisSpacing: AppSpacing.sm,

            crossAxisSpacing: AppSpacing.sm,

            childAspectRatio: 0.72,

          ),

          itemCount: products.length,

          itemBuilder: (context, index) =>

              _ProductGridCard(product: products[index]),

        ),
            ),
          ],
        );

      },

    );

  }

}



class _ProductGridCard extends ConsumerWidget {

  const _ProductGridCard({required this.product});



  final Product product;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    return Material(

      color: AppColors.white,

      borderRadius: BorderRadius.circular(16),

      clipBehavior: Clip.antiAlias,

      child: InkWell(

        onTap: () => showAdminProductEditor(context, ref, product: product),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            Expanded(

              flex: 3,

              child: Stack(

                fit: StackFit.expand,

                children: [

                  ProductThumbnail.fromProduct(

                    product: product,

                    width: double.infinity,

                    height: double.infinity,

                    borderRadius: 0,

                  ),

                  Positioned(

                    top: 8,

                    right: 8,

                    child: _AvailabilityChip(available: product.isAvailable),

                  ),

                ],

              ),

            ),

            Expanded(

              flex: 2,

              child: Padding(

                padding: const EdgeInsets.all(AppSpacing.sm),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      localizedOrRaw(product.nameKey),

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: Theme.of(context).textTheme.titleSmall,

                    ),

                    Text(

                      adminCategoryLabel(product.category),

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(

                            color: AppColors.textSecondary,

                          ),

                    ),

                    const Spacer(),

                    Row(

                      children: [

                        Expanded(

                          child: Text(

                            formatProductPrice(product.price),

                            style: Theme.of(context)

                                .textTheme

                                .titleMedium

                                ?.copyWith(color: AppColors.primary),

                          ),

                        ),

                        Switch(

                          value: product.isAvailable,

                          materialTapTargetSize:

                              MaterialTapTargetSize.shrinkWrap,

                          onChanged: (v) => ref

                              .read(adminProductsProvider.notifier)

                              .toggleAvailability(product.id, v),

                        ),

                        PopupMenuButton<String>(

                          icon: const Icon(Icons.more_vert, size: 20),

                          itemBuilder: (_) => [

                            PopupMenuItem(

                              value: 'edit',

                              child: Text(LocaleKeys.commonEdit.tr()),

                            ),

                            PopupMenuItem(

                              value: 'delete',

                              child: Text(

                                LocaleKeys.commonRemove.tr(),

                                style: const TextStyle(color: AppColors.error),

                              ),

                            ),

                          ],

                          onSelected: (value) async {

                            if (value == 'edit') {

                              showAdminProductEditor(

                                context,

                                ref,

                                product: product,

                              );

                            } else if (value == 'delete') {

                              final confirm =

                                  await showAdminDeleteConfirm(context);

                              if (confirm == true) {

                                await ref

                                    .read(adminProductsProvider.notifier)

                                    .deleteProduct(product.id);

                              }

                            }

                          },

                        ),

                      ],

                    ),

                  ],

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



class _AvailabilityChip extends StatelessWidget {

  const _AvailabilityChip({required this.available});



  final bool available;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(

        color: (available ? AppColors.success : AppColors.error)

            .withValues(alpha: 0.9),

        borderRadius: BorderRadius.circular(20),

      ),

      child: Text(

        available

            ? LocaleKeys.branchAvailable.tr()

            : LocaleKeys.branchSoldOut.tr(),

        style: const TextStyle(color: AppColors.white, fontSize: 10),

      ),

    );

  }

}



class _CampaignsTab extends ConsumerWidget {

  const _CampaignsTab();



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final bannersAsync = ref.watch(campaignBannersProvider);



    return bannersAsync.when(

      loading: () => const Center(child: CircularProgressIndicator()),

      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),

      data: (banners) {

        if (banners.isEmpty) {

          return Center(child: Text(LocaleKeys.adminNoCampaigns.tr()));

        }

        return ListView.separated(

          padding: const EdgeInsets.all(AppSpacing.md),

          itemCount: banners.length,

          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),

          itemBuilder: (context, index) =>

              _CampaignCard(banner: banners[index]),

        );

      },

    );

  }

}



class _CampaignCard extends ConsumerWidget {

  const _CampaignCard({required this.banner});



  final CampaignBanner banner;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    return Card(

      clipBehavior: Clip.antiAlias,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          SizedBox(

            height: 120,

            child: banner.imageUrl != null && banner.imageUrl!.isNotEmpty

                ? AppImage(

                    source: banner.imageUrl,

                    fit: BoxFit.cover,

                    errorWidget: _gradientFallback(banner),

                  )

                : _gradientFallback(banner),

          ),

          ListTile(

            title: Text(
              banner.title.trim().isEmpty
                  ? LocaleKeys.adminCampaignPreview.tr()
                  : localizedOrRaw(banner.title),
              style: banner.title.trim().isEmpty
                  ? const TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    )
                  : null,
            ),

            subtitle: Text(

              banner.isActive

                  ? LocaleKeys.adminCampaignActive.tr()

                  : LocaleKeys.adminCampaignInactive.tr(),

            ),

            trailing: Wrap(

              spacing: AppSpacing.xs,

              crossAxisAlignment: WrapCrossAlignment.center,

              children: [

                Switch(

                  value: banner.isActive,

                  onChanged: (v) => ref

                      .read(campaignBannersProvider.notifier)

                      .toggleActive(banner.id, v),

                ),

                IconButton(

                  icon: const Icon(Icons.edit_outlined),

                  onPressed: () => showAdminCampaignEditor(
                    context,
                    ref,
                    banner: banner,
                  ),

                ),

                IconButton(

                  icon: const Icon(Icons.delete_outline,

                      color: AppColors.error),

                  onPressed: () async {

                    final confirm = await showAdminDeleteConfirm(context);

                    if (confirm == true) {

                      await ref

                          .read(campaignBannersProvider.notifier)

                          .deleteBanner(banner.id);

                    }

                  },

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _gradientFallback(CampaignBanner banner) {

    return Container(

      decoration: BoxDecoration(

        gradient: LinearGradient(

          colors: [AppColors.primary, AppColors.primaryDark],

        ),

      ),

      alignment: banner.title.trim().isNotEmpty
          ? Alignment.bottomLeft
          : Alignment.center,
      padding: banner.title.trim().isNotEmpty
          ? const EdgeInsets.all(AppSpacing.md)
          : EdgeInsets.zero,
      child: banner.title.trim().isNotEmpty
          ? Text(
              localizedOrRaw(banner.title),
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,

    );

  }

}


