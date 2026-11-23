import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/security_repository_impl.dart';
import '../../domain/models/security_settings.dart';
import '../../domain/repositories/security_repository.dart';
import '../../domain/usecases/reset_passcode_usecase.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepositoryImpl();
});

final resetPasscodeUseCaseProvider = Provider<ResetPasscodeUseCase>((ref) {
  final repo = ref.watch(securityRepositoryProvider);
  return ResetPasscodeUseCase(repo);
});

class SecuritySettingsNotifier extends AsyncNotifier<SecuritySettings> {
  @override
  FutureOr<SecuritySettings> build() async {
    final repo = ref.watch(securityRepositoryProvider);
    return repo.getSettings();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(securityRepositoryProvider);
      return repo.getSettings();
    });
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final repo = ref.read(securityRepositoryProvider);
    await repo.setAppLockEnabled(enabled);
    await refresh();
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final repo = ref.read(securityRepositoryProvider);
    await repo.setBiometricsEnabled(enabled);
    await refresh();
  }

  Future<void> setLockOnExitEnabled(bool enabled) async {
    final repo = ref.read(securityRepositoryProvider);
    await repo.setLockOnExitEnabled(enabled);
    await refresh();
  }

  Future<void> savePin(String pin) async {
    final repo = ref.read(securityRepositoryProvider);
    await repo.savePin(pin);
    await refresh();
  }

  Future<void> removePin() async {
    final repo = ref.read(securityRepositoryProvider);
    await repo.removePin();
    await refresh();
  }

  Future<bool> verifyPin(String pin) async {
    final repo = ref.read(securityRepositoryProvider);
    final valid = await repo.verifyPin(pin);
    await refresh();
    return valid;
  }

  Future<bool> authenticateBiometrics() async {
    final repo = ref.read(securityRepositoryProvider);
    final success = await repo.authenticateWithBiometrics(
      localizedReason: 'استخدم بصمتك لفتح تطبيق باقي وحماية معاملاتك المالية',
    );
    await refresh();
    return success;
  }

  Future<String> resetPasscodeAndSendEmail({
    required String email,
    String? userName,
  }) async {
    final useCase = ref.read(resetPasscodeUseCaseProvider);
    final newPin = await useCase.execute(
      email: email,
      userName: userName,
    );
    await refresh();
    return newPin;
  }
}

final securitySettingsProvider =
    AsyncNotifierProvider<SecuritySettingsNotifier, SecuritySettings>(
  SecuritySettingsNotifier.new,
);

class AppLockStateNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void lock() => state = true;
  void unlock() => state = false;
}

final isAppLockedProvider =
    NotifierProvider<AppLockStateNotifier, bool>(AppLockStateNotifier.new);
