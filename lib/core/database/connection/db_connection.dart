import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'secure_key_storage.dart';

LazyDatabase openEncryptedConnection({
  DatabaseKeyStorage? keyStorage,
  File? file,
}) {
  return LazyDatabase(() async {
    final sw = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('[DB_PERF] Opening encrypted database connection...');
    }
    final storage = keyStorage ?? SecureDatabaseKeyStorage();
    final encryptionKey = await storage.getOrCreateKey();
    if (kDebugMode) {
      debugPrint('[DB_PERF] Encryption key resolved in ${sw.elapsedMilliseconds}ms');
    }

    final dbFile = file ??
        File(p.join(
          (await getApplicationDocumentsDirectory()).path,
          'baqy_encrypted.sqlite',
        ));

    if (kDebugMode) {
      debugPrint('[DB_PERF] Database file path: ${dbFile.path}');
    }

    return NativeDatabase.createInBackground(
      dbFile,
      setup: (rawDb) {
        final setupSw = Stopwatch()..start();
        // Enforce SQLCipher raw 256-bit key encryption
        rawDb.execute("PRAGMA key = \"x'$encryptionKey'\";");
        rawDb.execute('PRAGMA foreign_keys = ON;');
        if (kDebugMode) {
          debugPrint('[DB_PERF] SQLCipher PRAGMA setup completed in ${setupSw.elapsedMilliseconds}ms');
        }
      },
    );
  });
}

