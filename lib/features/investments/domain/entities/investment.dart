import 'package:equatable/equatable.dart';

enum InvestmentType {
  mutualFund,
  fixedDeposit,
  recurringDeposit,
  gold,
  realEstate,
  stock;

  String get label => switch (this) {
        InvestmentType.mutualFund => 'Mutual Fund',
        InvestmentType.fixedDeposit => 'Fixed Deposit',
        InvestmentType.recurringDeposit => 'Recurring Deposit',
        InvestmentType.gold => 'Gold',
        InvestmentType.realEstate => 'Real Estate',
        InvestmentType.stock => 'Stocks',
      };

  String get emoji => switch (this) {
        InvestmentType.mutualFund => '📈',
        InvestmentType.fixedDeposit => '🏦',
        InvestmentType.recurringDeposit => '🔄',
        InvestmentType.gold => '🥇',
        InvestmentType.realEstate => '🏠',
        InvestmentType.stock => '📊',
      };

  String get shortLabel => switch (this) {
        InvestmentType.mutualFund => 'MF',
        InvestmentType.fixedDeposit => 'FD',
        InvestmentType.recurringDeposit => 'RD',
        InvestmentType.gold => 'Gold',
        InvestmentType.realEstate => 'Property',
        InvestmentType.stock => 'Stocks',
      };
}

class Investment extends Equatable {
  final String id;
  final InvestmentType type;
  final String name;

  /// Total principal invested
  final double investedAmount;

  /// Current market value
  final double currentValue;

  final DateTime startDate;
  final DateTime? maturityDate;

  /// Annual interest rate % (for FD / RD)
  final double? interestRate;

  /// Units (MF), grams (Gold), shares (Stock)
  final double? quantity;

  /// Purchase price per unit / gram / share
  final double? purchasePrice;

  /// Current price per unit / gram / share
  final double? currentPrice;

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Investment({
    required this.id,
    required this.type,
    required this.name,
    required this.investedAmount,
    required this.currentValue,
    required this.startDate,
    this.maturityDate,
    this.interestRate,
    this.quantity,
    this.purchasePrice,
    this.currentPrice,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get gainLoss => currentValue - investedAmount;
  double get gainLossPercent =>
      investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0.0;
  bool get isProfit => gainLoss >= 0;

  Investment copyWith({
    InvestmentType? type,
    String? name,
    double? investedAmount,
    double? currentValue,
    DateTime? startDate,
    DateTime? maturityDate,
    bool clearMaturity = false,
    double? interestRate,
    double? quantity,
    double? purchasePrice,
    double? currentPrice,
    String? notes,
  }) =>
      Investment(
        id: id,
        type: type ?? this.type,
        name: name ?? this.name,
        investedAmount: investedAmount ?? this.investedAmount,
        currentValue: currentValue ?? this.currentValue,
        startDate: startDate ?? this.startDate,
        maturityDate: clearMaturity ? null : maturityDate ?? this.maturityDate,
        interestRate: interestRate ?? this.interestRate,
        quantity: quantity ?? this.quantity,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        currentPrice: currentPrice ?? this.currentPrice,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'investedAmount': investedAmount,
        'currentValue': currentValue,
        'startDate': startDate.toIso8601String(),
        'maturityDate': maturityDate?.toIso8601String(),
        'interestRate': interestRate,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'currentPrice': currentPrice,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Investment.fromJson(Map<String, dynamic> json) => Investment(
        id: json['id'] as String,
        type: InvestmentType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => InvestmentType.mutualFund,
        ),
        name: json['name'] as String,
        investedAmount: (json['investedAmount'] as num).toDouble(),
        currentValue: (json['currentValue'] as num).toDouble(),
        startDate: DateTime.parse(json['startDate'] as String),
        maturityDate: json['maturityDate'] != null
            ? DateTime.parse(json['maturityDate'] as String)
            : null,
        interestRate: json['interestRate'] != null
            ? (json['interestRate'] as num).toDouble()
            : null,
        quantity: json['quantity'] != null
            ? (json['quantity'] as num).toDouble()
            : null,
        purchasePrice: json['purchasePrice'] != null
            ? (json['purchasePrice'] as num).toDouble()
            : null,
        currentPrice: json['currentPrice'] != null
            ? (json['currentPrice'] as num).toDouble()
            : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        investedAmount,
        currentValue,
        updatedAt,
      ];
}
