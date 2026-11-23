class NewerSchemaVersionException implements Exception {
  final int snapshotVersion;
  final int currentVersion;

  const NewerSchemaVersionException({
    required this.snapshotVersion,
    required this.currentVersion,
  });

  @override
  String toString() =>
      'NewerSchemaVersionException: snapshot version $snapshotVersion is newer than app version $currentVersion';
}

class EmptyDatabaseOverwriteException implements Exception {
  const EmptyDatabaseOverwriteException();

  @override
  String toString() =>
      'EmptyDatabaseOverwriteException: cannot overwrite existing backup with empty database';
}

class CorruptedBackupException implements Exception {
  final String message;
  const CorruptedBackupException(this.message);

  @override
  String toString() => 'CorruptedBackupException: $message';
}

class BackupNotFoundException implements Exception {
  const BackupNotFoundException();

  @override
  String toString() => 'BackupNotFoundException: no cloud backup found';
}
