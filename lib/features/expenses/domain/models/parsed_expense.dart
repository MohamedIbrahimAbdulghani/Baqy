class ParsedExpenseCategoryProposal {
  final String name;
  final String icon;
  final String color;

  const ParsedExpenseCategoryProposal({
    required this.name,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'color': color,
      };

  factory ParsedExpenseCategoryProposal.fromJson(Map<String, dynamic> json) {
    return ParsedExpenseCategoryProposal(
      name: (json['name'] as String?)?.trim() ?? '',
      icon: (json['icon'] as String?)?.trim() ?? 'more_horiz',
      color: (json['color'] as String?)?.trim() ??
          (json['colorHex'] as String?)?.trim() ??
          '#4E8B7A',
    );
  }
}

class ParsedExpense {
  final int? amount; // in EGP. Nullable if only foreign currency was spoken
  final String description; // Short item name
  final String category;
  final String? note; // Optional place note
  final String? sourceText;
  final double confidence;
  final bool isNewCategory;
  final ParsedExpenseCategoryProposal? newCategoryProposal;
  final double? foreignAmount;
  final String? foreignCurrency;
  final String? quantityText; // Specification/weight/count info (e.g. "ربع جنيه", "2 جرام")

  const ParsedExpense({
    required this.amount,
    required this.description,
    required this.category,
    this.note,
    this.sourceText,
    this.confidence = 1.0,
    this.isNewCategory = false,
    this.newCategoryProposal,
    this.foreignAmount,
    this.foreignCurrency,
    this.quantityText,
  });

  bool get needsReview =>
      confidence < 0.6 || amount == null || (amount != null && amount! <= 0);

  String get name => description;

  int get amountInPiastres => (amount ?? 0) * 100;

  ParsedExpense copyWith({
    int? amount,
    bool clearAmount = false,
    String? description,
    String? category,
    String? note,
    String? sourceText,
    double? confidence,
    bool? isNewCategory,
    ParsedExpenseCategoryProposal? newCategoryProposal,
    bool clearProposal = false,
    double? foreignAmount,
    String? foreignCurrency,
    String? quantityText,
  }) {
    return ParsedExpense(
      amount: clearAmount ? null : (amount ?? this.amount),
      description: description ?? this.description,
      category: category ?? this.category,
      note: note ?? this.note,
      sourceText: sourceText ?? this.sourceText,
      confidence: confidence ?? this.confidence,
      isNewCategory: isNewCategory ?? this.isNewCategory,
      newCategoryProposal:
          clearProposal ? null : (newCategoryProposal ?? this.newCategoryProposal),
      foreignAmount: foreignAmount ?? this.foreignAmount,
      foreignCurrency: foreignCurrency ?? this.foreignCurrency,
      quantityText: quantityText ?? this.quantityText,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'description': description,
        'category': category,
        if (note != null) 'note': note,
        if (sourceText != null) 'source_text': sourceText,
        'confidence': confidence,
        'is_new_category': isNewCategory,
        if (newCategoryProposal != null)
          'new_category': newCategoryProposal!.toJson(),
        if (foreignAmount != null) 'foreign_amount': foreignAmount,
        if (foreignCurrency != null) 'foreign_currency': foreignCurrency,
        if (quantityText != null) 'quantity_text': quantityText,
      };

  factory ParsedExpense.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'] ?? json['amount_egp'];
    final int? amountVal = rawAmount is num ? rawAmount.toInt() : null;

    final rawForeignAmount = json['foreign_amount'];
    final double? foreignAmt =
        rawForeignAmount is num ? rawForeignAmount.toDouble() : null;

    final isNewCat = json['is_new_category'] as bool? ?? false;
    ParsedExpenseCategoryProposal? proposal;
    if (json['new_category'] is Map<String, dynamic>) {
      proposal = ParsedExpenseCategoryProposal.fromJson(
          json['new_category'] as Map<String, dynamic>);
    }

    return ParsedExpense(
      amount: amountVal,
      description: json['description'] as String? ?? '',
      category: (json['category_name'] ?? json['category']) as String? ?? 'أخرى',
      note: json['note'] as String?,
      sourceText: json['source_text'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      isNewCategory: isNewCat,
      newCategoryProposal: proposal,
      foreignAmount: foreignAmt,
      foreignCurrency: json['foreign_currency'] as String?,
      quantityText: json['quantity_text'] as String?,
    );
  }

  @override
  String toString() =>
      '$category ${amount != null ? "$amount EGP" : "No EGP"}${foreignAmount != null ? " (≈ $foreignAmount $foreignCurrency)" : ""} ("$description"${quantityText != null ? ', qty: "$quantityText"' : ''}${note != null ? ', note: "$note"' : ''}${sourceText != null ? ', source: "$sourceText"' : ''}, conf: $confidence${isNewCategory ? ", [NEW_CAT]" : ""})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedExpense &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          description == other.description &&
          category == other.category &&
          note == other.note &&
          sourceText == other.sourceText &&
          confidence == other.confidence &&
          isNewCategory == other.isNewCategory &&
          foreignAmount == other.foreignAmount &&
          foreignCurrency == other.foreignCurrency &&
          quantityText == other.quantityText;

  @override
  int get hashCode => Object.hash(
        amount,
        description,
        category,
        note,
        sourceText,
        confidence,
        isNewCategory,
        foreignAmount,
        foreignCurrency,
        quantityText,
      );
}
