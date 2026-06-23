import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<bool> showOperationalDataPurgeDialog({
  required BuildContext context,
  required String title,
  required String description,
}) async {
  final controller = TextEditingController();
  final confirmWord = LocaleKeys.opsDataPurgeConfirmWord.tr();
  var matches = false;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(description),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    LocaleKeys.opsDataPurgeConfirmHint.tr(
                      namedArgs: {'word': confirmWord},
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: confirmWord,
                    ),
                    onChanged: (value) {
                      setState(() {
                        matches = value.trim().toUpperCase() ==
                            confirmWord.toUpperCase();
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(LocaleKeys.commonCancel.tr()),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: matches ? () => Navigator.pop(dialogContext, true) : null,
                child: Text(LocaleKeys.opsDataPurgeConfirmButton.tr()),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
  return confirmed == true;
}

void showOperationalPurgeSuccessSnackBar(
  BuildContext context, {
  required int orders,
  required int reviews,
  required int remittances,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        LocaleKeys.opsDataPurgeSuccess.tr(
          namedArgs: {
            'orders': '$orders',
            'reviews': '$reviews',
            'remittances': '$remittances',
          },
        ),
      ),
    ),
  );
}
