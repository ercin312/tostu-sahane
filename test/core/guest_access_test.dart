import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/app/router/route_paths.dart';
import 'package:tostu_sahane/core/auth/guest_access.dart';

void main() {
  group('GuestAccess', () {
    test('allows menu and product browse without account', () {
      expect(GuestAccess.isBrowsablePath(RoutePaths.customerHome), isTrue);
      expect(GuestAccess.isBrowsablePath(RoutePaths.customerCart), isTrue);
      expect(
        GuestAccess.isBrowsablePath(RoutePaths.customerProduct('abc')),
        isTrue,
      );
    });

    test('blocks account-based customer routes', () {
      expect(GuestAccess.isBrowsablePath(RoutePaths.customerOrders), isFalse);
      expect(GuestAccess.isBrowsablePath(RoutePaths.customerProfile), isFalse);
      expect(GuestAccess.isBrowsablePath(RoutePaths.customerCheckout), isFalse);
      expect(
        GuestAccess.isBrowsablePath(RoutePaths.customerAddresses),
        isFalse,
      );
    });

    test('loginLocation encodes redirect', () {
      final loc = GuestAccess.loginLocation(
        redirectTo: RoutePaths.customerCheckout,
      );
      expect(loc, contains(RoutePaths.authLogin));
      expect(loc, contains('redirect='));
      expect(
        GuestAccess.redirectFromUri(Uri.parse(loc)),
        RoutePaths.customerCheckout,
      );
    });
  });
}
