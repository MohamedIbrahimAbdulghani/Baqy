import 'dart:async';
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
        _isGoogleSignInInitialized = true;
      } catch (_) {
        _isGoogleSignInInitialized = true;
      }
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
      final account = await _googleSignIn.authenticate();
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
    } on FirebaseAuthException catch (e) {
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
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
      final freshUser = _firebaseAuth.currentUser;
      if (freshUser == null) {
        return AccountStatus.deleted;
      }
      return AccountStatus.active;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled') {
        return AccountStatus.disabled;
      } else if (e.code == 'user-not-found') {
        return AccountStatus.deleted;
      }
      return AccountStatus.active;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('user-disabled') || str.contains('disabled')) {
        return AccountStatus.disabled;
      }
      if (str.contains('user-not-found') || str.contains('deleted')) {
        return AccountStatus.deleted;
      }
      return AccountStatus.active;
    }
  }
}
