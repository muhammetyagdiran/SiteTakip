enum TransactionType { income, expense }

class IncomeExpense {
  final String id;
  final String siteId;
  final String title;
  final String? description;
  final double amount;
  final TransactionType type;
  final bool isAutomatic; // True if generated from paid dues
  final DateTime date;
  final String createdBy;

  IncomeExpense({
    required this.id,
    required this.siteId,
    required this.title,
    this.description,
    required this.amount,
    required this.type,
    required this.isAutomatic,
    required this.date,
    required this.createdBy,
  });

  factory IncomeExpense.fromMap(Map<String, dynamic> map) {
    return IncomeExpense(
      id: map['id'],
      siteId: map['site_id'],
      title: map['title'],
      description: map['description'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'expense' ? TransactionType.expense : TransactionType.income,
      isAutomatic: map['is_automatic'] ?? false,
      date: DateTime.parse(map['transaction_date'] ?? map['created_at']).toLocal(),
      createdBy: map['created_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'site_id': siteId,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type == TransactionType.expense ? 'expense' : 'income',
      'is_automatic': isAutomatic,
      'transaction_date': date.toUtc().toIso8601String(),
      'created_by': createdBy,
    };
  }
}
