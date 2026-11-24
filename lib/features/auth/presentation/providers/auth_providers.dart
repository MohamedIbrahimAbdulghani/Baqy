import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/connection/account_database_manager.dart';
import '../../../../core/routing/app_router.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  final authAsync = ref.watch(authStateChangesProvider);
  return authAsync.value ?? ref.watch(authRepositoryProvider).currentUser;
});

final accountDatabaseManagerProvider = Provider<AccountDatabaseManager>((ref) {
  return AccountDatabaseManager();
});

class ActiveDatabaseNotifier extends Notifier<AppDatabase?> {
  @override
  AppDatabase? build() => null;

  void setDatabase(AppDatabase? db) => state = db;
}

final activeDatabaseProvider =
    NotifierProvider<ActiveDatabaseNotifier, AppDatabase?>(
  ActiveDatabaseNotifier.new,
);

class ActiveUserIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final user = ref.watch(currentUserProvider);
    return user?.uid;
  }

  void setUserId(String? id) => state = id;
}

final activeUserIdProvider =
    NotifierProvider<ActiveUserIdNotifier, String?>(
  ActiveUserIdNotifier.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signInWithGoogle() async {
    isAccountSuspended = false;
    isCheckingAccountSecurity = false;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithGoogle();
      if (user == null) {
        return;
      }

      final dbManager = ref.read(accountDatabaseManagerProvider);
      final db = await dbManager.openDatabaseForAccount(user.uid);

      final oldDb = ref.read(activeDatabaseProvider);
      if (oldDb != null && oldDb != db) {
        await oldDb.close();
      }

      ref.read(activeDatabaseProvider.notifier).setDatabase(db);
      ref.read(activeUserIdProvider.notifier).setUserId(user.uid);
    });

    if (state.hasError) {
      return false;
    }
    return ref.read(activeUserIdProvider) != null;
  }

  Future<void> signOut() async {
    isSigningOut = true;
    isAccountSuspended = false;
    isCheckingAccountSecurity = false;
    try {
      final currentDb = ref.read(activeDatabaseProvider);
      ref.read(activeDatabaseProvider.notifier).setDatabase(null);
      ref.read(activeUserIdProvider.notifier).setUserId(null);

      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
      if (currentDb != null) {
        await currentDb.close();
      }
    } finally {
      isSigningOut = false;
    }
  }

  Future<void> initializeForCurrentUser() async {
    final repo = ref.read(authRepositoryProvider);
    final user = repo.currentUser;
    if (user != null) {
      final dbManager = ref.read(accountDatabaseManagerProvider);
      final db = await dbManager.openDatabaseForAccount(user.uid);
      ref.read(activeDatabaseProvider.notifier).setDatabase(db);
      ref.read(activeUserIdProvider.notifier).setUserId(user.uid);
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
