import 'package:flutter/material.dart';

import '../../shared/domain/entities/product.dart';

import '../constants/app_assets.dart';

import '../media/app_image.dart';

import '../theme/app_colors.dart';

import 'app_logo.dart';



class ProductThumbnail extends StatelessWidget {

  const ProductThumbnail({

    super.key,

    required this.category,

    this.imageColorValue = 0xFFFFE0E6,

    this.imageUrl,

    this.width = 100,

    this.height = 100,

    this.borderRadius = 12,

    this.compact = false,

  });



  ProductThumbnail.fromProduct({

    super.key,

    required Product product,

    this.width = 100,

    this.height = 100,

    this.borderRadius = 12,

    this.compact = false,

  })  : category = product.category,

        imageColorValue = product.imageColorValue,

        imageUrl = product.imageUrl;



  final ProductCategory category;

  final int imageColorValue;

  final String? imageUrl;

  final double width;

  final double height;

  final double borderRadius;

  final bool compact;



  IconData get _categoryIcon {

    return switch (category) {

      ProductCategory.tost => Icons.lunch_dining_rounded,

      ProductCategory.sahanda => Icons.egg_alt_rounded,

      ProductCategory.drink => Icons.local_drink_rounded,

      ProductCategory.snack => Icons.fastfood_rounded,

      ProductCategory.combo => Icons.restaurant_menu_rounded,

      ProductCategory.all => Icons.restaurant_rounded,

    };

  }



  Color get _accentColor {

    final base = Color(imageColorValue);

    return Color.lerp(base, AppColors.primary, 0.35) ?? AppColors.primary;

  }



  @override

  Widget build(BuildContext context) {

    if (imageUrl != null && imageUrl!.isNotEmpty) {

      return AppImage(

        source: imageUrl,

        width: width,

        height: height,

        fit: BoxFit.cover,

        borderRadius: BorderRadius.circular(borderRadius),

        errorWidget: _placeholder(),

      );

    }



    return _placeholder();

  }



  Widget _placeholder() {

    final baseColor = Color(imageColorValue);



    return ClipRRect(

      borderRadius: BorderRadius.circular(borderRadius),

      child: SizedBox(

        width: width,

        height: height,

        child: Stack(

          fit: StackFit.expand,

          children: [

            DecoratedBox(

              decoration: BoxDecoration(

                gradient: LinearGradient(

                  begin: Alignment.topLeft,

                  end: Alignment.bottomRight,

                  colors: [

                    baseColor,

                    Color.lerp(baseColor, Colors.white, 0.45)!,

                  ],

                ),

              ),

            ),

            Positioned(

              right: -width * 0.15,

              bottom: -height * 0.2,

              child: Opacity(

                opacity: 0.12,

                child: Image.asset(

                  AppAssets.logoPng,

                  width: width * 0.9,

                  height: width * 0.9,

                  fit: BoxFit.contain,

                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),

                ),

              ),

            ),

            Center(

              child: Icon(

                _categoryIcon,

                size: compact ? width * 0.38 : width * 0.44,

                color: _accentColor,

              ),

            ),

            if (!compact)

              Positioned(

                left: 6,

                bottom: 6,

                child: Opacity(

                  opacity: 0.85,

                  child: AppLogo(height: width * 0.18),

                ),

              ),

          ],

        ),

      ),

    );

  }

}


