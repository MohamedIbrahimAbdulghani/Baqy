import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/baqy_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/security_providers.dart';
import '../widgets/pin_keypad.dart';

enum _ForgotPasscodeDialog { none, confirm, success, noEmail, error }

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _enteredDigits = '';
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _hasAttemptedAutoBiometric = false;
  bool _isResetting = false;
  _ForgotPasscodeDialog _activeDialog = _ForgotPasscodeDialog.none;
  String? _dialogEmail;
  String? _resetErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockoutAndInit();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _checkLockoutAndInit() {
    final settingsAsync = ref.read(securitySettingsProvider);
    settingsAsync.whenData((settings) {
      if (settings.isLockedOut) {
        _startCountdown(settings.lockoutSecondsRemaining);
      } else if (settings.isBiometricsEnabled && !_hasAttemptedAutoBiometric) {
        _hasAttemptedAutoBiometric = true;
        _tryBiometrics();
      }
    });
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = seconds;
      _errorMessage =
          'تم استنفاد المحاولات. يُرجى الانتظار $_secondsRemaining ثانية';
      _enteredDigits = '';
      _hasError = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _hasError = false;
          _errorMessage = '';
          ref.read(securityRepositoryProvider).resetFailedAttempts();
          ref.read(securitySettingsProvider.notifier).refresh();
        } else {
          _errorMessage =
              'تم استنفاد المحاولات. يُرجى الانتظار $_secondsRemaining ثانية';
        }
      });
    });
  }

  Future<void> _tryBiometrics() async {
    if (_secondsRemaining > 0) return;
    final success = await ref
        .read(securitySettingsProvider.notifier)
        .authenticateBiometrics();
    if (!mounted) return;
    if (success) {
      ref.read(isAppLockedProvider.notifier).unlock();
    }
  }

  void _onDigitTap(int digit) {
    if (_secondsRemaining > 0 || _enteredDigits.length >= 4) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _enteredDigits += digit.toString();
    });

    if (_enteredDigits.length == 4) {
      _verifyPin(_enteredDigits);
    }
  }

  void _onDeleteTap() {
    if (_secondsRemaining > 0 || _enteredDigits.isEmpty) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _enteredDigits = _enteredDigits.substring(0, _enteredDigits.length - 1);
    });
  }

  Future<void> _onPastePinTap() async {
    if (_secondsRemaining > 0) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 4) {
        final pin = digits.substring(0, 4);
        setState(() {
          _enteredDigits = pin;
          _hasError = false;
          _errorMessage = '';
        });
        await _verifyPin(pin);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يتم العثور على 4 أرقام في الحافظة للصقها',
              style: TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _verifyPin(String pin) async {
    final valid = await ref
        .read(securitySettingsProvider.notifier)
        .verifyPin(pin);
    if (!mounted) return;

    if (valid) {
      ref.read(isAppLockedProvider.notifier).unlock();
    } else {
      final settings = ref.read(securitySettingsProvider).value;
      if (settings != null && settings.isLockedOut) {
        _startCountdown(settings.lockoutSecondsRemaining);
      } else {
        final remainingAttempts = settings != null
            ? (5 - settings.failedAttempts).clamp(1, 5)
            : 4;
        setState(() {
          _hasError = true;
          _errorMessage =
              'رمز المرور غير صحيح (متبقي $remainingAttempts محاولات)';
          _enteredDigits = '';
        });
      }
    }
  }

  void _onForgotPasswordTap() {
    if (_isResetting) return;

    String? email;
    try {
      final user = ref.read(currentUserProvider);
      email = user?.email?.trim();
    } catch (_) {}

    if (email == null || email.isEmpty) {
      setState(() {
        _activeDialog = _ForgotPasscodeDialog.noEmail;
      });
      return;
    }

    setState(() {
      _dialogEmail = email;
      _activeDialog = _ForgotPasscodeDialog.confirm;
    });
  }

  void _dismissDialog() {
    setState(() {
      _activeDialog = _ForgotPasscodeDialog.none;
    });
  }

  Future<void> _handleConfirmReset(String email) async {
    setState(() {
      _isResetting = true;
    });

    try {
      String? displayName;
      try {
        displayName = ref.read(currentUserProvider)?.displayName;
      } catch (_) {}

      await ref
          .read(securitySettingsProvider.notifier)
          .resetPasscodeAndSendEmail(email: email, userName: displayName);

      _countdownTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isResetting = false;
        _secondsRemaining = 0;
        _enteredDigits = '';
        _hasError = false;
        _errorMessage = '';
        _activeDialog = _ForgotPasscodeDialog.success;
      });
    } catch (e) {
      if (!mounted) return;
      final cleanMessage = e
          .toString()
          .replaceFirst('Exception: ', '')
          .trim();
      setState(() {
        _isResetting = false;
        _resetErrorMessage = cleanMessage.isNotEmpty
            ? cleanMessage
            : 'تعذر إرسال رمز المرور إلى بريدك الإلكتروني حالياً. يُرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى لاحقاً.';
        _activeDialog = _ForgotPasscodeDialog.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(securitySettingsProvider);
    final isBiometricsEnabled =
        settingsAsync.value?.isBiometricsEnabled ?? false;
    final isLockedOut = _secondsRemaining > 0;
    final email = _dialogEmail ?? '';

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // App Branding Logo with subtle green box
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.darkGreen.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: BaqyLogo(size: 44, isSplash: false),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Header Title
                      Text(
                        'أهلاً بك مجدداً',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Instruction / Error subtitle
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _errorMessage.isNotEmpty
                              ? _errorMessage
                              : 'أدخل رمز المرور لفتح التطبيق وتأمين معاملاتك',
                          key: ValueKey(_errorMessage),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _hasError
                                ? AppColors.errorRed
                                : AppColors.secondaryText,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Dots
                      PinDots(
                        length: _enteredDigits.length,
                        totalLength: 4,
                        hasError: _hasError,
                      ),

                      const SizedBox(height: 8),

                      // Paste Passcode Button
                      TextButton.icon(
                        onPressed: isLockedOut ? null : _onPastePinTap,
                        icon: Icon(
                          Icons.content_paste_rounded,
                          size: 14,
                          color: AppColors.secondaryText,
                        ),
                        label: Text(
                          'لصق رمز المرور',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Numeric Keypad
                      PinKeypad(
                        onDigitTap: _onDigitTap,
                        onDeleteTap: _onDeleteTap,
                        onBiometricTap: isBiometricsEnabled
                            ? _tryBiometrics
                            : null,
                        showBiometrics: isBiometricsEnabled,
                        isDisabled: isLockedOut,
                      ),

                      const SizedBox(height: 16),

                      // Forgot Passcode Button
                      TextButton.icon(
                        onPressed: _isResetting ? null : _onForgotPasswordTap,
                        icon: _isResetting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.darkGreen,
                                ),
                              )
                            : Icon(
                                Icons.help_outline_rounded,
                                size: 18,
                                color: AppColors.secondaryText,
                              ),
                        label: Text(
                          _isResetting
                              ? 'جارٍ إرسال رمز جديد...'
                              : 'نسيت رمز المرور؟',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isResetting
                                ? AppColors.darkGreen
                                : AppColors.secondaryText,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_activeDialog != _ForgotPasscodeDialog.none)
            Positioned.fill(child: _buildDialogOverlay(email)),
        ],
      ),
    );
  }

  Widget _buildDialogOverlay(String email) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _buildDialogContent(email),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogContent(String email) {
    switch (_activeDialog) {
      case _ForgotPasscodeDialog.confirm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.darkGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'استعادة رمز المرور',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'هل نسيت رمز المرور؟ سيتم إنشاء رمز مرور جديد وإرساله تلقائياً إلى بريدك الإلكتروني المسجل:',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.subtleButton,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.darkGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ستتمكن من استخدام الرمز الجديد فوراً لفتح التطبيق، ويمكنك تغييره لاحقاً من صفحة الإعدادات.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isResetting ? null : _dismissDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      side: BorderSide(color: AppColors.dividers),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isResetting
                        ? null
                        : () => _handleConfirmReset(email),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: _isResetting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'إرسال رمز جديد',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );

      case _ForgotPasscodeDialog.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.darkGreen,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'تم إرسال رمز المرور',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'تم إنشاء رمز مرور جديد وإرساله بنجاح إلى بريدك الإلكتروني المسجل:\n$email\n\nيُرجى التحقق من صندوق الوارد (أو مجلد الرسائل غير المرغوب فيها Spam) لمعرفة رمز المرور الجديد واستخدامه لفتح التطبيق.',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dismissDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'حسناً',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );

      case _ForgotPasscodeDialog.noEmail:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'استعادة رمز المرور',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر العثور على بريد إلكتروني مرتبط بحسابك. يُرجى تسجيل الدخول مجدداً.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _dismissDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'حسناً',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );

      case _ForgotPasscodeDialog.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.errorRed,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'تعذر إرسال رمز المرور',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _resetErrorMessage ??
                  'تعذر إرسال رمز المرور إلى بريدك الإلكتروني حالياً. يُرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى لاحقاً.',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dismissDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text(
                  'حسناً',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );

      case _ForgotPasscodeDialog.none:
        return const SizedBox.shrink();
    }
  }
}
