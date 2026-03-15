import 'dart:convert';
import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/investment.dart';

class InvestmentLocalDatasource {
  List<Investment> getAll() {
    final box = HiveService.investments;
    return box.values
        .map((v) => Investment.fromJson(
            Map<String, dynamic>.from(jsonDecode(v as String) as Map)))
        .toList();
  }

  Future<void> save(Investment investment) async {
    await HiveService.investments
        .put(investment.id, jsonEncode(investment.toJson()));
  }

  Future<void> delete(String id) async {
    await HiveService.investments.delete(id);
  }

  Future<void> clear() async {
    await HiveService.investments.clear();
  }
}
