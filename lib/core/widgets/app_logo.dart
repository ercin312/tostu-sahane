import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 48,
    this.color,
    this.onPrimary = false,
  });

  final double height;
  final Color? color;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (onPrimary ? AppColors.white : null);

    return SvgPicture.asset(
      AppAssets.logoSvg,
      height: height,
      colorFilter: tint != null
          ? ColorFilter.mode(tint, BlendMode.srcIn)
          : null,
    );
  }
}

class AppLogoBadge extends StatelessWidget {
  const AppLogoBadge({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppLogo(height: size * 0.76),
    );
  }
}
