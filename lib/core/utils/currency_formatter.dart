import 'package:intl/intl.dart';

abstract class CurrencyFormatter {
  static String _currencyCode = 'INR';
  static String _baseCurrencyCode = 'INR';
  static Map<String, double> _exchangeRates = {'INR': 1.0};
  static bool _privacyModeEnabled = false;
  static final Map<String, NumberFormat> _formatters = {};
  static final Map<String, NumberFormat> _decimalFormatters = {};
  static final Map<String, NumberFormat> _compactFormatters = {};

  static void setCurrency(String code) {
    _currencyCode = code.trim().toUpperCase();
  }

  static void setExchangeRates({
    required String baseCurrency,
    required Map<String, double> rates,
  }) {
    final normalizedBase = baseCurrency.trim().toUpperCase();
    _baseCurrencyCode = normalizedBase;
    _exchangeRates = {
      for (final entry in rates.entries)
        entry.key.trim().toUpperCase(): entry.value,
    };
    _exchangeRates[_baseCurrencyCode] = 1.0;
  }

  static void setPrivacyMode(bool enabled) {
    _privacyModeEnabled = enabled;
  }

  static bool get privacyModeEnabled => _privacyModeEnabled;

  static String get currencyCode => _currencyCode;

  static String get baseCurrencyCode => _baseCurrencyCode;

  static String symbol({String? currencyCode}) {
    final code = (currencyCode ?? _currencyCode).toUpperCase();
    return _currencySymbol(code);
  }

  static double convertFromBase(double amount, {String? toCurrencyCode}) {
    final target = (toCurrencyCode ?? _currencyCode).toUpperCase();
    final rate = _exchangeRates[target];
    if (target == _baseCurrencyCode || rate == null || rate <= 0) {
      return amount;
    }
    return amount * rate;
  }

  static String format(
    double amount, {
    bool showDecimals = false,
    String? currencyCode,
  }) {
    final code = (currencyCode ?? _currencyCode).toUpperCase();
    final convertedAmount = convertFromBase(amount, toCurrencyCode: code);
    if (_privacyModeEnabled) {
      return '${_currencySymbol(code)}••••';
    }
    final formatter = _resolveFormatter(code, showDecimals);
    return formatter.format(convertedAmount);
  }

  static String compact(double amount, {String? currencyCode}) {
    final code = (currencyCode ?? _currencyCode).toUpperCase();
    final symbol = _currencySymbol(code);
    final convertedAmount = convertFromBase(amount, toCurrencyCode: code);

    if (_privacyModeEnabled) {
      return '$symbol••••';
    }

    if (code == 'INR') {
      if (convertedAmount >= 10000000) {
        return '$symbol${(convertedAmount / 10000000).toStringAsFixed(1)}Cr';
      }
      if (convertedAmount >= 100000) {
        return '$symbol${(convertedAmount / 100000).toStringAsFixed(1)}L';
      }
      if (convertedAmount >= 1000) {
        return '$symbol${(convertedAmount / 1000).toStringAsFixed(1)}K';
      }
      final formatter = _resolveFormatter(code, false);
      return formatter.format(convertedAmount);
    }

    final formatter = _compactFormatters.putIfAbsent(code, () {
      return NumberFormat.compactCurrency(
        locale: _currencyLocale(code),
        symbol: symbol,
        decimalDigits: 1,
      );
    });
    return formatter.format(convertedAmount);
  }

  static String withSign(
    double amount, {
    bool showDecimals = false,
    String? currencyCode,
  }) {
    if (_privacyModeEnabled) {
      final code = (currencyCode ?? _currencyCode).toUpperCase();
      final masked = '${_currencySymbol(code)}••••';
      if (amount >= 0) return '+$masked';
      return '-$masked';
    }

    final formatted = format(
      amount,
      showDecimals: showDecimals,
      currencyCode: currencyCode,
    );
    if (amount >= 0) return '+$formatted';
    return formatted;
  }

  static NumberFormat _resolveFormatter(String code, bool showDecimals) {
    final symbol = _currencySymbol(code);
    if (showDecimals) {
      return _decimalFormatters.putIfAbsent(code, () {
        return NumberFormat.currency(
          locale: _currencyLocale(code),
          symbol: symbol,
          decimalDigits: 2,
        );
      });
    }

    return _formatters.putIfAbsent(code, () {
      return NumberFormat.currency(
        locale: _currencyLocale(code),
        symbol: symbol,
        decimalDigits: 0,
      );
    });
  }

  static String _currencySymbol(String code) {
    return switch (code) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'AED' => 'د.إ',
      'SGD' => r'S$',
      'CAD' => r'C$',
      'AUD' => r'A$',
      _ => '₹',
    };
  }

  static String _currencyLocale(String code) {
    return switch (code) {
      'USD' => 'en_US',
      'EUR' => 'en_IE',
      'GBP' => 'en_GB',
      'JPY' => 'ja_JP',
      'AED' => 'en_AE',
      'SGD' => 'en_SG',
      'CAD' => 'en_CA',
      'AUD' => 'en_AU',
      _ => 'en_IN',
    };
  }
}
