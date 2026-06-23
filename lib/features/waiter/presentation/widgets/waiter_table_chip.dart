import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';

class WaiterTableChip extends StatelessWidget {
  const WaiterTableChip({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.isOpen = false,
    this.totalAmount,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isOpen;
  final double? totalAmount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = isOpen
        ? AppColors.warning.withValues(alpha: 0.18)
        : AppColors.success.withValues(alpha: 0.12);
    final border = isOpen ? AppColors.warning : AppColors.success;
    final numberSize = compact ? 15.0 : 22.0;
    final totalSize = compact ? 10.0 : 13.0;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
            border: Border.all(color: border.withValues(alpha: 0.5)),
          ),
          padding: EdgeInsets.all(compact ? 4 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: numberSize,
                  fontWeight: FontWeight.bold,
                  color: isOpen ? AppColors.warning : AppColors.success,
                ),
              ),
              if (isOpen && totalAmount != null) ...[
                SizedBox(height: compact ? 1 : 4),
                Text(
                  FormatUtils.currency(totalAmount!),
                  style: TextStyle(
                    fontSize: totalSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    LocaleKeys.waiterTableOccupied.tr(),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
