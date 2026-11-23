import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/security_settings.dart';
import '../../domain/repositories/security_repository.dart';
import '../services/passcode_email_service.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  SecurityRepositoryImpl({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
    LocalAuthentication? localAuth,
    PasscodeEmailService? emailService,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _prefsInstance = prefs,
        _localAuth = localAuth ?? LocalAuthentication(),
        _emailService = emailService ?? PasscodeEmailServiceImpl();

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefsInstance;
  final LocalAuthentication _localAuth;
  final PasscodeEmailService _emailService;

  static const String _pinKey = 'baqy_user_passcode_hash';
  static const String _appLockEnabledKey = 'baqy_app_lock_enabled';
  static const String _biometricsEnabledKey = 'baqy_biometrics_enabled';
  static const String _lockOnExitEnabledKey = 'baqy_lock_on_exit_enabled';
  static const String _failedAttemptsKey = 'baqy_security_failed_attempts';
  static const String _lockedUntilKey = 'baqy_security_locked_until_ms';
  static const int maxFailedAttempts = 5;
  static const int lockoutSeconds = 60;

  static bool _biometricPromptActive = false;

  @override
  bool get isBiometricPromptActive => _biometricPromptActive;

  @override
  bool get isAppLockEnabledSync {
    final prefs = _prefsInstance;
    if (prefs == null) return false;
    return prefs.getBool(_appLockEnabledKey) ?? false;
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ??= await SharedPreferences.getInstance();
  }

  String _hashPin(String pin) {
    const salt = 'baqy_salt_financial_sec_2026';
    return sha256.convert(utf8.encode('$pin:$salt')).toString();
  }

  @override
  Future<SecuritySettings> getSettings() async {
    final prefs = await _getPrefs();
    final isAppLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
    final isBiometricsEnabled = prefs.getBool(_biometricsEnabledKey) ?? false;
    final lockOnExit = prefs.getBool(_lockOnExitEnabledKey) ?? true;
    final failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    final lockedUntilMs = prefs.getInt(_lockedUntilKey);
    final hasPinSet = await hasPin();
    final isBiometricsSupported = await isBiometricsAvailable();

    DateTime? lockedUntil;
    if (lockedUntilMs != null && lockedUntilMs > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);
      if (DateTime.now().isBefore(date)) {
        lockedUntil = date;
      } else {
        // Expired lockout: clear it
        await prefs.remove(_lockedUntilKey);
        await prefs.setInt(_failedAttemptsKey, 0);
      }
    }

    return SecuritySettings(
      isAppLockEnabled: isAppLockEnabled && hasPinSet,
      isBiometricsEnabled: isBiometricsEnabled && isBiometricsSupported,
      lockOnExit: lockOnExit,
      failedAttempts: failedAttempts,
      lockedUntil: lockedUntil,
      hasPinSet: hasPinSet,
      isBiometricsSupported: isBiometricsSupported,
    );
  }

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticateWithBiometrics({
    required String localizedReason,
  }) async {
    _biometricPromptActive = true;
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      final success = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (success) {
        await resetFailedAttempts();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      // Small buffer to allow Android window focus to transition back to resumed
      await Future.delayed(const Duration(milliseconds: 300));
      _biometricPromptActive = false;
    }
  }

  @override
  Future<bool> hasPin() async {
    try {
      final hash = await _secureStorage.read(key: _pinKey);
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _pinKey);
      if (storedHash == null) return false;
      final inputHash = _hashPin(pin);
      if (storedHash == inputHash) {
        await resetFailedAttempts();
        return true;
      }
      await recordFailedAttempt();
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> savePin(String pin) async {
    final hash = _hashPin(pin);
    await _secureStorage.write(key: _pinKey, value: hash);
    final prefs = await _getPrefs();
    await prefs.setBool(_appLockEnabledKey, true);
    await prefs.setBool(_lockOnExitEnabledKey, true);
    await resetFailedAttempts();
  }

  @override
  Future<void> removePin() async {
    await _secureStorage.delete(key: _pinKey);
    final prefs = await _getPrefs();
    await prefs.setBool(_appLockEnabledKey, false);
    await prefs.setBool(_biometricsEnabledKey, false);
    await resetFailedAttempts();
  }

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_appLockEnabledKey, enabled);
    if (!enabled) {
      await prefs.setBool(_biometricsEnabledKey, false);
    }
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_biometricsEnabledKey, enabled);
  }

  @override
  Future<void> setLockOnExitEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_lockOnExitEnabledKey, enabled);
  }

  @override
  Future<SecuritySettings> recordFailedAttempt() async {
    final prefs = await _getPrefs();
    final current = (prefs.getInt(_failedAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_failedAttemptsKey, current);

    DateTime? lockedUntil;
    if (current >= maxFailedAttempts) {
      lockedUntil = DateTime.now().add(const Duration(seconds: lockoutSeconds));
      await prefs.setInt(_lockedUntilKey, lockedUntil.millisecondsSinceEpoch);
    }

    final isAppLockEnabled = prefs.getBool(_appLockEnabledKey) ?? false;
    final isBiometricsEnabled = prefs.getBool(_biometricsEnabledKey) ?? false;
    final lockOnExit = prefs.getBool(_lockOnExitEnabledKey) ?? true;
    final hasPinSet = await hasPin();
    final isBiometricsSupported = await isBiometricsAvailable();

    return SecuritySettings(
      isAppLockEnabled: isAppLockEnabled && hasPinSet,
      isBiometricsEnabled: isBiometricsEnabled && isBiometricsSupported,
      lockOnExit: lockOnExit,
      failedAttempts: current,
      lockedUntil: lockedUntil,
      hasPinSet: hasPinSet,
      isBiometricsSupported: isBiometricsSupported,
    );
  }

  @override
  Future<void> resetFailedAttempts() async {
    final prefs = await _getPrefs();
    await prefs.setInt(_failedAttemptsKey, 0);
    await prefs.remove(_lockedUntilKey);
  }

  @override
  Future<String> generateAndSaveNewPin() async {
    final random = Random.secure();
    final newPin = (1000 + random.nextInt(9000)).toString();
    await savePin(newPin);
    await resetFailedAttempts();
    return newPin;
  }

  @override
  Future<bool> sendPasscodeResetEmail({
    required String email,
    required String newPin,
    String? userName,
  }) async {
    return _emailService.sendPasscodeResetEmail(
      recipientEmail: email,
      newPasscode: newPin,
      userName: userName,
    );
  }
}
