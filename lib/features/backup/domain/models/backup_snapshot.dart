class BackupSnapshot {
  final int schemaVersion;
  final DateTime createdAt;
  final Map<String, List<Map<String, dynamic>>> tables;

  const BackupSnapshot({
    required this.schemaVersion,
    required this.createdAt,
    required this.tables,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  factory BackupSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'] as Map<String, dynamic>? ?? {};
    final tablesMap = <String, List<Map<String, dynamic>>>{};

    rawTables.forEach((tableName, rowsList) {
      if (rowsList is List) {
        tablesMap[tableName] = rowsList
            .whereType<Map<String, dynamic>>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
    });

    DateTime parsedDate;
    final rawCreated = json['createdAt'];
    if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now().toUtc();
    } else {
      parsedDate = DateTime.now().toUtc();
    }

    return BackupSnapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      createdAt: parsedDate,
      tables: tablesMap,
    );
  }
}
