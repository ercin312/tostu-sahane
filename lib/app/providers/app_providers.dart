import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../router/app_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authProvider);
  return createAppRouter(ref);
});
