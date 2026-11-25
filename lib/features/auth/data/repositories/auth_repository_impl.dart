import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/exceptions/auth_exceptions.dart';
import '../../domain/models/account_status.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _isGoogleSignInInitialized = false;

  static const String _serverClientId =
      '340670824976-hqsu4qg4lgv0m5n6kn5nu1vu8vqtuo8p.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (!_isGoogleSignInInitialized) {
      try {
        await _googleSignIn.initialize(
          serverClientId: _serverClientId,
        );
      } catch (_) {}
      _isGoogleSignInInitialized = true;
    }
  }

  @override
  Stream<AuthUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return AuthUser(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
      );
    });
  }

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    String? userEmail;
    try {
      await _ensureInitialized();
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e, st) {
        debugPrint('[AUTH_DEBUG] authenticate caught: ${e.code} - ${e.description}\n$st');
        if (e.description?.contains('No credential') ?? false) {
          try {
            debugPrint('[AUTH_DEBUG] Trying attemptLightweightAuthentication fallback...');
            account = await _googleSignIn.attemptLightweightAuthentication();
          } catch (e2, st2) {
            debugPrint('[AUTH_DEBUG] attemptLightweightAuthentication fallback caught: $e2\n$st2');
          }
        }
        if (account == null) {
          if (e.code == GoogleSignInExceptionCode.canceled ||
              (e.description?.contains('No credential') ?? false)) {
            return null;
          }
          rethrow;
        }
      }

      userEmail = account.email;
      final idToken = account.authentication.idToken;

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('User is null after sign in');
      }

      // Check account status immediately with Firebase server
      final status = await checkAccountStatus();
      if (status == AccountStatus.disabled) {
        await signOut();
        throw AccountDisabledException(
          'لا يمكنك تسجيل الدخول بهذا الحساب، لأن هذا البريد الإلكتروني معطّل حالياً من قِبل إدارة التطبيق.\n\nإذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يُرجى التواصل مع إدارة التطبيق عبر واتساب أو جيميل لإعادة تفعيله.',
          userEmail,
        );
      } else if (status == AccountStatus.deleted) {
        await signOut();
        throw AccountDeletedException(
          'لا يمكنك تسجيل الدخول بهذا الحساب، لأن هذا البريد الإلكتروني تم حذفه نهائياً من قِبل إدارة التطبيق.',
          userEmail,
        );
      }

      return AuthUser(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AUTH_DEBUG] FirebaseAuthException: ${e.code} - ${e.message}\n$st');
      if (e.code == 'user-disabled') {
        throw AccountDisabledException(
          'لا يمكنك تسجيل الدخول بهذا الحساب، لأن هذا البريد الإلكتروني معطّل حالياً من قِبل إدارة التطبيق.\n\nإذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يُرجى التواصل مع إدارة التطبيق عبر واتساب أو جيميل لإعادة تفعيله.',
          userEmail,
        );
      } else if (e.code == 'user-not-found') {
        throw AccountDeletedException(
          'لا يمكنك تسجيل الدخول بهذا الحساب، لأن هذا البريد الإلكتروني تم حذفه نهائياً من قِبل إدارة التطبيق.',
          userEmail,
        );
      }
      rethrow;
    } on GoogleSignInException catch (e, st) {
      debugPrint('[AUTH_DEBUG] GoogleSignInException: ${e.code} - ${e.description}\n$st');
      if (e.code == GoogleSignInExceptionCode.canceled ||
          (e.description?.contains('No credential') ?? false)) {
        return null;
      }
      rethrow;
    } catch (e, st) {
      debugPrint('[AUTH_DEBUG] Unexpected signIn error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      unawaited(_googleSignIn.signOut());
    } catch (_) {}
  }

  @override
  Future<AccountStatus> checkAccountStatus() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return AccountStatus.active;
    }
    try {
      await user.reload();
      await user.getIdToken(true);
      if (_firebaseAuth.currentUser == null) {
        return AccountStatus.active;
      }
      return AccountStatus.active;
    } on FirebaseAuthException catch (e) {
      if (_firebaseAuth.currentUser == null) {
        return AccountStatus.active;
      }
      if (e.code == 'user-disabled') {
        return AccountStatus.disabled;
      } else if (e.code == 'user-not-found') {
        return AccountStatus.deleted;
      }
      return AccountStatus.active;
    } catch (e) {
      if (_firebaseAuth.currentUser == null) {
        return AccountStatus.active;
      }
      final str = e.toString().toLowerCase();
      if (str.contains('user-disabled')) {
        return AccountStatus.disabled;
      }
      if (str.contains('user-not-found')) {
        return AccountStatus.deleted;
      }
      return AccountStatus.active;
    }
  }
}
