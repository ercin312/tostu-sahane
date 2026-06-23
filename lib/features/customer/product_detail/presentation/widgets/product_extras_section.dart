import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';



import '../../../../../core/localization/locale_keys.dart';

import '../../../../../core/media/app_image.dart';

import '../../../../../core/theme/app_colors.dart';

import '../../../../../core/theme/app_spacing.dart';

import '../../../../../core/utils/format_utils.dart';

import '../../../../../core/utils/localized_text.dart';

import '../../../../../shared/domain/entities/product_extra.dart';



class ProductExtrasSection extends StatelessWidget {

  const ProductExtrasSection({

    super.key,

    required this.extras,

    required this.selectedIds,

    required this.onToggle,

  });



  final List<ProductExtra> extras;

  final Set<String> selectedIds;

  final ValueChanged<ProductExtra> onToggle;



  @override

  Widget build(BuildContext context) {

    if (extras.isEmpty) return const SizedBox.shrink();



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    LocaleKeys.customerExtrasTitle.tr(),

                    style: Theme.of(context).textTheme.titleLarge?.copyWith(

                          fontWeight: FontWeight.w700,

                        ),

                  ),

                  if (LocaleKeys.customerExtrasSubtitle.tr().isNotEmpty) ...[

                    const SizedBox(height: 2),

                    Text(

                      LocaleKeys.customerExtrasSubtitle.tr(),

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(

                            color: AppColors.textSecondary,

                          ),

                    ),

                  ],

                ],

              ),

            ),

            Container(

              padding: const EdgeInsets.symmetric(

                horizontal: AppSpacing.sm,

                vertical: 4,

              ),

              decoration: BoxDecoration(

                color: AppColors.divider.withValues(alpha: 0.6),

                borderRadius: BorderRadius.circular(20),

              ),

              child: Text(

                LocaleKeys.customerExtrasOptional.tr(),

                style: Theme.of(context).textTheme.labelSmall?.copyWith(

                      color: AppColors.textSecondary,

                      fontWeight: FontWeight.w600,

                    ),

              ),

            ),

          ],

        ),

        const SizedBox(height: AppSpacing.md),

        ...extras.map(

          (extra) => _ExtraTile(

            extra: extra,

            selected: selectedIds.contains(extra.id),

            onTap: () => onToggle(extra),

          ),

        ),

      ],

    );

  }

}



class _ExtraTile extends StatelessWidget {

  const _ExtraTile({

    required this.extra,

    required this.selected,

    required this.onTap,

  });



  final ProductExtra extra;

  final bool selected;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    final name = localizedOrRaw(extra.name);



    return Padding(

      padding: const EdgeInsets.only(bottom: AppSpacing.sm),

      child: Material(

        color: selected

            ? AppColors.primary.withValues(alpha: 0.06)

            : AppColors.white,

        borderRadius: BorderRadius.circular(14),

        child: InkWell(

          onTap: onTap,

          borderRadius: BorderRadius.circular(14),

          child: Container(

            padding: const EdgeInsets.all(AppSpacing.sm),

            decoration: BoxDecoration(

              borderRadius: BorderRadius.circular(14),

              border: Border.all(

                color: selected

                    ? AppColors.primary.withValues(alpha: 0.45)

                    : AppColors.divider,

                width: selected ? 1.5 : 1,

              ),

            ),

            child: Row(

              children: [

                ClipRRect(

                  borderRadius: BorderRadius.circular(10),

                  child: SizedBox(

                    width: 56,

                    height: 56,

                    child: extra.imageUrl != null && extra.imageUrl!.isNotEmpty

                        ? AppImage(

                            source: extra.imageUrl,

                            fit: BoxFit.cover,

                            errorWidget: _extraPlaceholder(extra),

                          )

                        : _extraPlaceholder(extra),

                  ),

                ),

                const SizedBox(width: AppSpacing.sm),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        name,

                        style: Theme.of(context).textTheme.titleSmall?.copyWith(

                              fontWeight: FontWeight.w600,

                            ),

                      ),

                      if (extra.price > 0)

                        Text(

                          LocaleKeys.customerExtraPriceAdd.tr(

                            namedArgs: {

                              'price': FormatUtils.currency(extra.price),

                            },

                          ),

                          style:

                              Theme.of(context).textTheme.bodySmall?.copyWith(

                                    color: AppColors.textSecondary,

                                  ),

                        )

                      else

                        Text(

                          LocaleKeys.commonFree.tr(),

                          style:

                              Theme.of(context).textTheme.bodySmall?.copyWith(

                                    color: AppColors.success,

                                  ),

                        ),

                    ],

                  ),

                ),

                AnimatedContainer(

                  duration: const Duration(milliseconds: 180),

                  width: 26,

                  height: 26,

                  decoration: BoxDecoration(

                    color: selected ? AppColors.primary : Colors.transparent,

                    borderRadius: BorderRadius.circular(6),

                    border: Border.all(

                      color: selected ? AppColors.primary : AppColors.divider,

                      width: 2,

                    ),

                  ),

                  child: selected

                      ? const Icon(Icons.check, size: 16, color: AppColors.white)

                      : null,

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _extraPlaceholder(ProductExtra extra) {

    return ColoredBox(

      color: AppColors.primary.withValues(alpha: 0.08),

      child: Icon(

        Icons.fastfood_outlined,

        color: AppColors.primary.withValues(alpha: 0.5),

      ),

    );

  }

}


