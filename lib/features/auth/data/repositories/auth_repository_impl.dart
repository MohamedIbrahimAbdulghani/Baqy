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

  Future<void> _ensureInitialized() async {
    if (!_isGoogleSignInInitialized) {
      try {
        await _googleSignIn.initialize();
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
    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('User is null after sign in');
      }

      return AuthUser(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled') {
        throw const AccountDisabledException();
      } else if (e.code == 'user-not-found') {
        throw const AccountDeletedException();
      }
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User closed the account picker silently
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
    } catch (_) {
      return AccountStatus.active;
    }
  }
}
