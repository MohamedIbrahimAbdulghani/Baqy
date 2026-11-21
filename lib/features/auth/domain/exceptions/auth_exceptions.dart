class AccountDisabledException implements Exception {
  const AccountDisabledException([
    this.message =
        'تم تعطيل هذا الحساب من قِبل إدارة التطبيق لمراجعة النشاط أو لمخالفة شروط الاستخدام.',
    this.email,
  ]);

  final String message;
  final String? email;

  @override
  String toString() => message;
}

class AccountDeletedException implements Exception {
  const AccountDeletedException([
    this.message =
        'تم حذف بيانات هذا الحساب نهائياً من قِبل إدارة التطبيق.',
    this.email,
  ]);

  final String message;
  final String? email;

  @override
  String toString() => message;
}
