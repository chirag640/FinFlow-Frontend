import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String name;
  final double monthlyIncome;
  final String? phone;
  final String? email;
  final String currencyCode;
  final DateTime createdAt;

  const AppUser({
    required this.name,
    required this.monthlyIncome,
    this.phone,
    this.email,
    this.currencyCode = 'INR',
    required this.createdAt,
  });

  AppUser copyWith({
    String? name,
    double? monthlyIncome,
    String? phone,
    String? email,
    String? currencyCode,
  }) {
    return AppUser(
      name: name ?? this.name,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'monthlyIncome': monthlyIncome,
    'phone': phone,
    'email': email,
    'currencyCode': currencyCode,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    name: j['name'] as String,
    monthlyIncome: (j['monthlyIncome'] as num).toDouble(),
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    currencyCode: (j['currencyCode'] as String?) ?? 'INR',
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  @override
  List<Object?> get props => [name, monthlyIncome, phone, email];
}
