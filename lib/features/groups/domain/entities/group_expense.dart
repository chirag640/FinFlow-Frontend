import 'package:equatable/equatable.dart';

enum SplitType { equal, custom, percentage, incomeRatio }

class SplitShare {
  final String memberId;
  final double amount;
  final double? percentage;

  const SplitShare({
    required this.memberId,
    required this.amount,
    this.percentage,
  });

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'amount': amount,
        'percentage': percentage,
      };

  factory SplitShare.fromJson(Map<String, dynamic> j) => SplitShare(
        memberId: j['memberId'] as String,
        amount: (j['amount'] as num).toDouble(),
        percentage: j['percentage'] != null
            ? (j['percentage'] as num).toDouble()
            : null,
      );
}

class GroupExpense extends Equatable {
  final String id;
  final String groupId;
  final double amount;
  final String description;
  final String paidByMemberId;
  final SplitType splitType;
  final List<SplitShare> shares;
  final DateTime date;
  final String? note;
  final bool isSettlement;

  const GroupExpense({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.description,
    required this.paidByMemberId,
    required this.splitType,
    required this.shares,
    required this.date,
    this.note,
    this.isSettlement = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'amount': amount,
        'description': description,
        'paidByMemberId': paidByMemberId,
        'splitType': splitType.name,
        'shares': shares.map((s) => s.toJson()).toList(),
        'date': date.toIso8601String(),
        'note': note,
        'isSettlement': isSettlement,
      };

  factory GroupExpense.fromJson(Map<String, dynamic> j) => GroupExpense(
        id: (j['id'] ?? j['_id']) as String,
        groupId: j['groupId'] as String,
        amount: (j['amount'] as num).toDouble(),
        description: j['description'] as String,
        paidByMemberId: j['paidByMemberId'] as String,
        splitType: SplitType.values.byName(j['splitType'] as String),
        shares: (j['shares'] as List)
            .map((s) => SplitShare.fromJson(s as Map<String, dynamic>))
            .toList(),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
        isSettlement: j['isSettlement'] as bool? ?? false,
      );

  /// Parses a GroupExpenseDoc returned directly by the NestJS API (uses _id).
  factory GroupExpense.fromServerJson(Map<String, dynamic> j) =>
      GroupExpense.fromJson({
        ...j,
        'id': j['_id'] ?? j['id'],
        'date': j['date'] is String
            ? j['date']
            : (j['date'] as DateTime).toIso8601String(),
      });

  @override
  List<Object?> get props => [id, groupId, amount, isSettlement];
}

class SettleUpTransaction {
  final String fromId;
  final String toId;
  final double amount;

  const SettleUpTransaction({
    required this.fromId,
    required this.toId,
    required this.amount,
  });
}

/// Debt simplification: minimizes number of transactions needed
List<SettleUpTransaction> simplifyDebts(Map<String, double> balances) {
  final result = <SettleUpTransaction>[];
  final debtors = balances.entries
      .where((e) => e.value < -0.01)
      .map((e) => MapEntry(e.key, e.value))
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final creditors = balances.entries
      .where((e) => e.value > 0.01)
      .map((e) => MapEntry(e.key, e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  int i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final debt = -debtors[i].value;
    final credit = creditors[j].value;
    final amount = debt < credit ? debt : credit;

    result.add(
      SettleUpTransaction(
        fromId: debtors[i].key,
        toId: creditors[j].key,
        amount: amount,
      ),
    );

    debtors[i] = MapEntry(debtors[i].key, debtors[i].value + amount);
    creditors[j] = MapEntry(creditors[j].key, creditors[j].value - amount);

    if (debtors[i].value.abs() < 0.01) i++;
    if (creditors[j].value.abs() < 0.01) j++;
  }

  return result;
}
