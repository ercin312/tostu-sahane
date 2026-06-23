import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../shared/data/mock/mock_data.dart';
import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product_extra.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/cart_item_display_utils.dart';
import '../utils/localized_text.dart';

class OrderCartItemRows extends ConsumerWidget {
  const OrderCartItemRows({
    super.key,
    required this.items,
    this.compact = false,
  });

  final List<CartItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog =
        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OrderCartItemRow(
              item: item,
              catalog: catalog,
              compact: compact,
            ),
          ),
      ],
    );
  }
}

class OrderCartItemRow extends StatelessWidget {
  const OrderCartItemRow({
    super.key,
    required this.item,
    required this.catalog,
    this.compact = false,
    this.onRemove,
  });

  final CartItem item;
  final List<ProductExtra> catalog;
  final bool compact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final extras = CartItemDisplayUtils.extraLabels(item, catalog);
    final titleStyle = compact
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodyLarge;
    final extraStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.quantity}x',
              style: titleStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CartItemDisplayUtils.productTitle(item),
                    style: titleStyle,
                  ),
                  if (item.portionKey != null)
                    Text(
                      localizedOrRaw(item.portionKey!),
                      style: extraStyle,
                    ),
                  if (extras.isNotEmpty)
                    Text(
                      '+ ${extras.join(', ')}',
                      style: extraStyle?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (item.note != null && item.note!.trim().isNotEmpty)
                    Text(
                      item.note!.trim(),
                      style: extraStyle?.copyWith(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.error,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                tooltip: '',
              ),
          ],
        ),
      ],
    );
  }
}
