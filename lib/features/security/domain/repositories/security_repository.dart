import '../models/security_settings.dart';

abstract class SecurityRepository {
  Future<SecuritySettings> getSettings();
  Future<bool> isBiometricsAvailable();
  Future<bool> authenticateWithBiometrics({required String localizedReason});
  Future<bool> hasPin();
  Future<bool> verifyPin(String pin);
  Future<void> savePin(String pin);
  Future<void> removePin();
  Future<void> setAppLockEnabled(bool enabled);
  Future<void> setBiometricsEnabled(bool enabled);
  Future<void> setLockOnExitEnabled(bool enabled);
  Future<SecuritySettings> recordFailedAttempt();
  Future<void> resetFailedAttempts();
  Future<String> generateAndSaveNewPin();
  Future<bool> sendPasscodeResetEmail({
    required String email,
    required String newPin,
    String? userName,
  });
}
