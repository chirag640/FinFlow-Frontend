import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../data/datasources/investment_local_datasource.dart';
import '../../domain/entities/investment.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class InvestmentsState {
  final List<Investment> investments;
  final bool isLoading;
  final String? error;

  const InvestmentsState({
    this.investments = const [],
    this.isLoading = false,
    this.error,
  });

  double get totalInvested =>
      investments.fold(0.0, (s, i) => s + i.investedAmount);

  double get totalCurrentValue =>
      investments.fold(0.0, (s, i) => s + i.currentValue);

  double get totalGainLoss => totalCurrentValue - totalInvested;

  double get totalGainLossPercent =>
      totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0.0;

  bool get isProfit => totalGainLoss >= 0;

  List<Investment> byType(InvestmentType type) =>
      investments.where((i) => i.type == type).toList();

  Map<InvestmentType, double> get valueByType {
    final map = <InvestmentType, double>{};
    for (final inv in investments) {
      map[inv.type] = (map[inv.type] ?? 0) + inv.currentValue;
    }
    return map;
  }

  InvestmentsState copyWith({
    List<Investment>? investments,
    bool? isLoading,
    Object? error = _sentinel,
  }) =>
      InvestmentsState(
        investments: investments ?? this.investments,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class InvestmentsNotifier extends StateNotifier<InvestmentsState> {
  final InvestmentLocalDatasource _ds;
  final Ref _ref;
  static const _uuid = Uuid();

  InvestmentsNotifier(this._ds, this._ref) : super(const InvestmentsState()) {
    _load();
    _syncFromCloud();
  }

  void _load() {
    final investments = _ds.getAll();
    investments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(investments: investments);
  }

  bool get _isConnected {
    final hasNetwork = _ref.read(connectivityProvider);
    final isAuthenticated = _ref.read(cloudAuthProvider).isConnected;
    return hasNetwork && isAuthenticated;
  }

  /// Fetch all investments from the backend and replace the local cache.
  Future<void> _syncFromCloud() async {
    if (!_isConnected) return;
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.investments);
      final list = (res.data['data']['investments'] as List?) ?? [];
      final serverInvestments = list
          .map((raw) => Investment.fromJson(raw as Map<String, dynamic>))
          .toList();
      for (final inv in serverInvestments) {
        await _ds.save(inv);
      }
      if (mounted) {
        serverInvestments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        state = state.copyWith(investments: serverInvestments, error: null);
      }
    } on DioException catch (e) {
      // Network unavailable — keep local cache
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
    }
  }

  Future<void> add(Investment investment) async {
    await _ds.save(investment);
    _load();
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post(ApiEndpoints.investments, data: investment.toJson());
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Server sync failed — local data already saved
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Future<void> update(Investment investment) async {
    await _ds.save(investment);
    _load();
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.patch(ApiEndpoints.investment(investment.id),
            data: investment.toJson());
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Server sync failed — local data already saved
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Future<void> delete(String id) async {
    await _ds.delete(id);
    _load();
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.delete(ApiEndpoints.investment(id));
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Server sync failed — local data already deleted
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Investment buildNew({
    required InvestmentType type,
    required String name,
    required double investedAmount,
    required double currentValue,
    required DateTime startDate,
    DateTime? maturityDate,
    double? interestRate,
    double? quantity,
    double? purchasePrice,
    double? currentPrice,
    String? notes,
  }) {
    final now = DateTime.now();
    return Investment(
      id: _uuid.v4(),
      type: type,
      name: name,
      investedAmount: investedAmount,
      currentValue: currentValue,
      startDate: startDate,
      maturityDate: maturityDate,
      interestRate: interestRate,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final investmentsProvider =
    StateNotifierProvider<InvestmentsNotifier, InvestmentsState>(
  (ref) => InvestmentsNotifier(InvestmentLocalDatasource(), ref),
);
