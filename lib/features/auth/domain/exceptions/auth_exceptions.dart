class AccountDisabledException implements Exception {
  const AccountDisabledException([
    this.message =
        'تم تعطيل هذا الحساب من قِبل إدارة التطبيق لمراجعة النشاط أو لمخالفة شروط الاستخدام.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AccountDeletedException implements Exception {
  const AccountDeletedException([
    this.message =
        'تم حذف بيانات هذا الحساب نهائياً من قِبل إدارة التطبيق.',
  ]);

  final String message;

  @override
  String toString() => message;
}
