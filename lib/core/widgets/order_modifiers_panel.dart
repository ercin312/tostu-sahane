import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../features/customer/home/presentation/providers/branch_provider.dart';

import '../../shared/data/mock/mock_data.dart';

import '../../shared/domain/entities/order.dart';

import '../../shared/domain/entities/product_extra.dart';

import '../localization/locale_keys.dart';

import '../theme/app_colors.dart';

import '../theme/app_spacing.dart';

import '../utils/cart_item_display_utils.dart';

import '../utils/order_modifiers_utils.dart';



/// Sipariş ekleri — iç sipariş / şube detayında ürün bazlı seçenekler.

class OrderModifiersPanel extends ConsumerWidget {

  const OrderModifiersPanel({

    super.key,

    required this.order,

    this.compact = false,

  });



  final Order order;

  final bool compact;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    if (!OrderModifiersUtils.hasModifiers(order)) {

      return const SizedBox.shrink();

    }



    final catalog =

        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;



    return Container(

      width: double.infinity,

      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),

      decoration: BoxDecoration(

        color: AppColors.primary.withValues(alpha: 0.04),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            LocaleKeys.orderModifiersTitle.tr(),

            style: Theme.of(context).textTheme.titleSmall?.copyWith(

                  fontWeight: FontWeight.w700,

                  color: AppColors.primary,

                ),

          ),

          ..._itemModifierBlocks(context, catalog),

        ],

      ),

    );

  }



  List<Widget> _itemModifierBlocks(

    BuildContext context,

    List<ProductExtra> catalog,

  ) {

    final blocks = <Widget>[];

    for (final item in order.items) {

      if (!OrderModifiersUtils.hasItemModifiers(item)) continue;

      final lines = OrderModifiersUtils.itemModifierLines(item, catalog);

      blocks.add(

        Padding(

          padding: const EdgeInsets.only(top: AppSpacing.xs),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                '${item.quantity}x ${CartItemDisplayUtils.productTitle(item)}',

                style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                      fontWeight: FontWeight.w600,

                    ),

              ),

              ...lines.map(

                (line) => Padding(

                  padding: const EdgeInsets.only(left: 8, top: 2),

                  child: Text(

                    line,

                    style: Theme.of(context).textTheme.bodySmall?.copyWith(

                          color: AppColors.textSecondary,

                          fontWeight: FontWeight.w500,

                        ),

                  ),

                ),

              ),

            ],

          ),

        ),

      );

    }

    return blocks;

  }

}


