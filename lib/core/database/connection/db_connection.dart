import 'dart:io';
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
    final storage = keyStorage ?? SecureDatabaseKeyStorage();
    final encryptionKey = await storage.getOrCreateKey();

    final dbFile = file ??
        File(p.join(
          (await getApplicationDocumentsDirectory()).path,
          'baqy_encrypted.sqlite',
        ));

    return NativeDatabase.createInBackground(
      dbFile,
      setup: (rawDb) {
        // Enforce SQLCipher raw 256-bit key encryption
        rawDb.execute("PRAGMA key = \"x'$encryptionKey'\";");
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}

