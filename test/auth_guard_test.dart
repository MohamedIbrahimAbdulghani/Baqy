import 'package:baqy/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    authCheckOverride = null;
  });

  tearDown(() {
    authCheckOverride = null;
  });

  group('Strict Auth Guard & Router Security Tests', () {
    test('Unauthenticated user attempting to access /main is strictly redirected to /sign-in', () {
      authCheckOverride = () => false;

      // Unauthenticated state
      expect(isUserAuthenticated(), isFalse);

      appRouter.go('/main');
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/sign-in'));
    });

    test('Unauthenticated user attempting to access /settings is redirected to /sign-in', () {
      authCheckOverride = () => false;

      appRouter.go('/settings');
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/sign-in'));
    });

    test('Unauthenticated user attempting to access /add-expense is redirected to /sign-in', () {
      authCheckOverride = () => false;

      appRouter.go('/add-expense');
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/sign-in'));
    });

    test('Unauthenticated user can access /sign-in without redirection', () {
      authCheckOverride = () => false;

      appRouter.go('/sign-in');
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/sign-in'));
    });

    test('Authenticated user attempting to visit /sign-in is redirected to /main', () {
      authCheckOverride = () => true;

      expect(isUserAuthenticated(), isTrue);

      appRouter.go('/sign-in');
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/main'));
    });

    test('Signing out immediately triggers auth guard redirect to /sign-in', () {
      // 1. Initially authenticated
      authCheckOverride = () => true;
      appRouter.go('/main');
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/main'));

      // 2. User signs out or account is disabled
      authCheckOverride = () => false;
      appAuthNotifier.notifyAuthChanged();

      // 3. Router immediately intercepts and enforces /sign-in
      expect(appRouter.routeInformationProvider.value.uri.path, equals('/sign-in'));
    });
  });
}
