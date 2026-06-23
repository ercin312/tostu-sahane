import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

abstract final class PlatformLayout {
  static const desktopBreakpoint = 960.0;

  static bool get isWeb => kIsWeb;

  /// Windows masaüstü operasyon sürümü (şube / yönetici PC).
  static bool get isOpsDesktop =>
      AppConfig.opsDesktop ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  static bool useDesktopLayout(BuildContext context) {
    if (isOpsDesktop || isWeb) return true;
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }
}
