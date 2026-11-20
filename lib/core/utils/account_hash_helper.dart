import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helper to derive a 16-hex character identifier from an account ID using SHA-256.
/// Ensures raw account IDs and emails are never used in file names or logs.
class AccountHashHelper {
  AccountHashHelper._();

  static String deriveIdentifier(String accountId) {
    final bytes = utf8.encode(accountId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
