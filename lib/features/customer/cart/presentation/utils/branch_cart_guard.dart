import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../providers/cart_provider.dart';

Future<void> selectBranchWithCartGuard(
  BuildContext context,
  WidgetRef ref,
  Branch newBranch,
) async {
  final cart = ref.read(cartProvider);
  final cartBranchId = ref.read(cartBranchIdProvider);

  if (cart.isEmpty ||
      cartBranchId == null ||
      cartBranchId == newBranch.id) {
    ref.read(cartBranchIdProvider.notifier).set(newBranch.id);
    await ref.read(branchProvider.notifier).selectBranch(newBranch);
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(LocaleKeys.cartBranchChangeTitle.tr()),
      content: Text(
        LocaleKeys.cartBranchChangeMessage.tr(
          namedArgs: {'branch': newBranch.name},
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(LocaleKeys.commonCancel.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            LocaleKeys.cartBranchChangeConfirm.tr(),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  ref.read(cartProvider.notifier).clear();
  ref.read(cartBranchIdProvider.notifier).set(newBranch.id);
  await ref.read(branchProvider.notifier).selectBranch(newBranch);
}
