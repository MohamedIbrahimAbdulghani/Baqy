class SecuritySettings {
  const SecuritySettings({
    this.isAppLockEnabled = false,
    this.isBiometricsEnabled = false,
    this.lockOnExit = true,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.hasPinSet = false,
    this.isBiometricsSupported = false,
  });

  final bool isAppLockEnabled;
  final bool isBiometricsEnabled;
  final bool lockOnExit;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final bool hasPinSet;
  final bool isBiometricsSupported;

  bool get isLockedOut =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  int get lockoutSecondsRemaining {
    if (!isLockedOut) return 0;
    return lockedUntil!.difference(DateTime.now()).inSeconds + 1;
  }

  SecuritySettings copyWith({
    bool? isAppLockEnabled,
    bool? isBiometricsEnabled,
    bool? lockOnExit,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool? hasPinSet,
    bool? isBiometricsSupported,
  }) {
    return SecuritySettings(
      isAppLockEnabled: isAppLockEnabled ?? this.isAppLockEnabled,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      lockOnExit: lockOnExit ?? this.lockOnExit,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      hasPinSet: hasPinSet ?? this.hasPinSet,
      isBiometricsSupported:
          isBiometricsSupported ?? this.isBiometricsSupported,
    );
  }
}
