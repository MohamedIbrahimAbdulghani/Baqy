class BackupMeta {
  final int schemaVersion;
  final int chunkCount;
  final DateTime updatedAt;
  final Map<String, int> tableCounts;
  final String contentHash;

  const BackupMeta({
    required this.schemaVersion,
    required this.chunkCount,
    required this.updatedAt,
    required this.tableCounts,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'chunkCount': chunkCount,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'tableCounts': tableCounts,
      'contentHash': contentHash,
    };
  }

  factory BackupMeta.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['updatedAt'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawCounts = json['tableCounts'] as Map<String, dynamic>? ?? {};
    final counts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

    return BackupMeta(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
      updatedAt: parsedDate,
      tableCounts: counts,
      contentHash: json['contentHash'] as String? ?? '',
    );
  }

  BackupMeta copyWith({
    int? schemaVersion,
    int? chunkCount,
    DateTime? updatedAt,
    Map<String, int>? tableCounts,
    String? contentHash,
  }) {
    return BackupMeta(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      chunkCount: chunkCount ?? this.chunkCount,
      updatedAt: updatedAt ?? this.updatedAt,
      tableCounts: tableCounts ?? this.tableCounts,
      contentHash: contentHash ?? this.contentHash,
    );
  }
}
