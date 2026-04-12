import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/auth_interceptor.dart';
import '../storage/hive_service.dart';
import '../utils/currency_formatter.dart';
import 'connectivity_provider.dart';
import 'settings_provider.dart';

abstract class _K {
  static const exchangeRateBaseCurrency = 'exchange_rate_base_currency';
  static const exchangeRateCacheJson = 'exchange_rate_cache_json';
  static const exchangeRateUpdatedAt = 'exchange_rate_updated_at';
}

class ExchangeRateState {
  final String baseCurrency;
  final Map<String, double> rates;
  final DateTime? updatedAt;
  final bool isLoading;
  final String? error;

  const ExchangeRateState({
    this.baseCurrency = 'INR',
    this.rates = const {'INR': 1.0},
    this.updatedAt,
    this.isLoading = false,
    this.error,
  });

  ExchangeRateState copyWith({
    String? baseCurrency,
    Map<String, double>? rates,
    DateTime? updatedAt,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return ExchangeRateState(
      baseCurrency: baseCurrency ?? this.baseCurrency,
      rates: rates ?? this.rates,
      updatedAt: updatedAt ?? this.updatedAt,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();

  double rateFor(String currencyCode) {
    final normalized = currencyCode.toUpperCase();
    if (normalized == baseCurrency.toUpperCase()) return 1.0;
    return rates[normalized] ?? 1.0;
  }

  double convert(
    double amount, {
    required String fromCurrency,
    required String toCurrency,
  }) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) return amount;

    final fromRate = from == baseCurrency.toUpperCase() ? 1.0 : rates[from];
    final toRate = to == baseCurrency.toUpperCase() ? 1.0 : rates[to];

    if (fromRate == null || fromRate <= 0 || toRate == null || toRate <= 0) {
      return amount;
    }

    final amountInBase =
        from == baseCurrency.toUpperCase() ? amount : amount / fromRate;
    return amountInBase * toRate;
  }
}

class ExchangeRateNotifier extends StateNotifier<ExchangeRateState> {
  final Ref _ref;

  ExchangeRateNotifier(this._ref) : super(const ExchangeRateState()) {
    _loadFromCache();
    unawaited(refreshIfStale());
  }

  static const Map<String, double> _fallbackRatesFromInr = {
    'INR': 1.0,
    'USD': 0.012,
    'EUR': 0.011,
    'GBP': 0.0095,
    'JPY': 1.8,
    'AED': 0.044,
    'SGD': 0.016,
    'CAD': 0.017,
    'AUD': 0.019,
  };

  void _loadFromCache() {
    final box = HiveService.settings;
    final cachedBase = (box.get(
      _K.exchangeRateBaseCurrency,
      defaultValue: 'INR',
    ) as String)
        .toUpperCase();
    final cacheJson = box.get(_K.exchangeRateCacheJson) as String?;
    final updatedAtRaw = box.get(_K.exchangeRateUpdatedAt) as String?;
    final updatedAt =
        updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw);

    Map<String, double> parsedRates = {};
    if (cacheJson != null && cacheJson.isNotEmpty) {
      try {
        final decoded = json.decode(cacheJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is num) {
            parsedRates[entry.key.toUpperCase()] = value.toDouble();
          }
        }
      } catch (_) {
        parsedRates = {};
      }
    }

    if (parsedRates.isEmpty) {
      parsedRates = Map<String, double>.from(_fallbackRatesFromInr);
    }
    parsedRates[cachedBase] = 1.0;

    state = state.copyWith(
      baseCurrency: cachedBase,
      rates: parsedRates,
      updatedAt: updatedAt,
    );
    _syncFormatterRates();
  }

  Future<void> refreshIfStale() async {
    final lastUpdated = state.updatedAt;
    final now = DateTime.now();
    final isStale = lastUpdated == null ||
        now.difference(lastUpdated) > const Duration(hours: 12);
    if (!isStale) return;
    await refreshRates();
  }

  Future<void> refreshRates() async {
    if (state.isLoading) return;

    if (!_ref.read(connectivityProvider)) {
      state = state.copyWith(error: 'No network. Using cached exchange rates.');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get(
        'https://open.er-api.com/v6/latest/${state.baseCurrency}',
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Unexpected exchange-rate payload.');
      }

      final result = (payload['result'] as String?)?.toLowerCase();
      final rawRates = payload['rates'];
      if (result != 'success' || rawRates is! Map<String, dynamic>) {
        throw const FormatException(
            'Exchange-rate API response was not successful.');
      }

      final supportedCodes = {
        for (final c in kSupportedCurrencies) c.code.toUpperCase(),
      };

      final updatedRates = <String, double>{};
      for (final code in supportedCodes) {
        final value = rawRates[code];
        if (value is num && value > 0) {
          updatedRates[code] = value.toDouble();
        }
      }

      if (updatedRates.isEmpty) {
        throw const FormatException('No supported currency rates returned.');
      }

      updatedRates[state.baseCurrency.toUpperCase()] = 1.0;
      final updatedAt = _parseServerTimestamp(payload['time_last_update_unix']);

      final box = HiveService.settings;
      await box.put(_K.exchangeRateBaseCurrency, state.baseCurrency);
      await box.put(_K.exchangeRateCacheJson, json.encode(updatedRates));
      await box.put(_K.exchangeRateUpdatedAt, updatedAt.toIso8601String());

      state = state.copyWith(
        rates: updatedRates,
        updatedAt: updatedAt,
        isLoading: false,
        error: null,
      );
      _syncFormatterRates();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to refresh exchange rates right now.',
      );
    }
  }

  DateTime _parseServerTimestamp(dynamic rawUnixSeconds) {
    if (rawUnixSeconds is num && rawUnixSeconds > 0) {
      return DateTime.fromMillisecondsSinceEpoch(rawUnixSeconds.toInt() * 1000);
    }
    return DateTime.now();
  }

  void _syncFormatterRates() {
    CurrencyFormatter.setExchangeRates(
      baseCurrency: state.baseCurrency,
      rates: state.rates,
    );
  }
}

final exchangeRateProvider =
    StateNotifierProvider<ExchangeRateNotifier, ExchangeRateState>((ref) {
  final notifier = ExchangeRateNotifier(ref);
  ref.listen<SettingsState>(settingsProvider, (_, next) {
    // Trigger background refresh after a currency switch so recent rates are available.
    unawaited(notifier.refreshIfStale());
    CurrencyFormatter.setCurrency(next.currency);
  });
  return notifier;
});
