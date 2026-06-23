import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

class OrderRatingSheet extends ConsumerStatefulWidget {
  const OrderRatingSheet({super.key, required this.order});

  final Order order;

  static Future<void> show(BuildContext context, Order order) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: OrderRatingSheet(order: order),
      ),
    );
  }

  @override
  ConsumerState<OrderRatingSheet> createState() => _OrderRatingSheetState();
}

class _OrderRatingSheetState extends ConsumerState<OrderRatingSheet> {
  var _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    await ref.read(ordersProvider.notifier).rateOrder(
          widget.order.id,
          _rating,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.productReviewPendingApproval.tr()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.orderRateTitle.tr(),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
              );
            }),
          ),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              labelText: LocaleKeys.orderRateComment.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _rating > 0 ? _submit : null,
            child: Text(LocaleKeys.orderRateSubmit.tr()),
          ),
        ],
      ),
    );
  }
}
