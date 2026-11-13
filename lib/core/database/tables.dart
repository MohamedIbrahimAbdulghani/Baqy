import 'package:drift/drift.dart';

@DataClassName('CategoryData')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get colorHex => text().named('color')();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get createdByAi => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('TransactionData')
@TableIndex(name: 'idx_transactions_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_transactions_category_created', columns: {#categoryId, #createdAt})
@TableIndex(name: 'idx_transactions_kind_created', columns: {#kind, #createdAt})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()(); // piastres in EGP
  TextColumn get description => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get kind => text()(); // "expense" or "income"
  TextColumn get source => text()(); // "voice" or "text" or "debt"
  TextColumn get note => text().nullable()();
  RealColumn get foreignAmount => real().nullable()(); // optional foreign currency amount
  TextColumn get foreignCurrency => text().nullable()(); // e.g. "USD", "EUR"
  DateTimeColumn get createdAt => dateTime()(); // UTC
}

@DataClassName('UserRuleData')
class UserRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get keyword => text()(); // normalized keyword
  IntColumn get categoryId => integer().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MonthBudgetData')
class MonthBudgets extends Table {
  TextColumn get yearMonth => text()(); // e.g. "2026-11"
  IntColumn get amount => integer()(); // piastres

  @override
  Set<Column> get primaryKey => {yearMonth};
}

@DataClassName('GoalData')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get targetAmount => integer()(); // piastres
  IntColumn get monthlySaving => integer()(); // piastres
  DateTimeColumn get createdAt => dateTime()(); // UTC
  TextColumn get icon => text().nullable()();
}

@DataClassName('GoalSavingData')
@TableIndex(name: 'idx_goal_savings_goal_id', columns: {#goalId})
@TableIndex(name: 'idx_goal_savings_saved_at', columns: {#savedAt})
class GoalSavings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get amount => integer()(); // piastres
  DateTimeColumn get savedAt => dateTime()(); // UTC
}

@DataClassName('ReminderData')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get amount => integer()(); // piastres
  DateTimeColumn get dueDate => dateTime()(); // UTC
  TextColumn get repeat => text()(); // "once" or "monthly"
  IntColumn get leadDays => integer()(); // 1, 2 or 3
}

@DataClassName('DebtData')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get personName => text()();
  TextColumn get direction => text()(); // "owe" or "owed"
  IntColumn get totalAmount => integer()(); // piastres
  DateTimeColumn get dueDate => dateTime().nullable()(); // UTC
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()(); // UTC
}

@DataClassName('DebtPaymentData')
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  IntColumn get amount => integer()(); // piastres
  DateTimeColumn get paidAt => dateTime()(); // UTC
}

