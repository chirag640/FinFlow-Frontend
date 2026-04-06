import 'package:intl/intl.dart';

abstract class CurrencyFormatter {
  static String _currencyCode = 'INR';
  static final Map<String, NumberFormat> _formatters = {};
  static final Map<String, NumberFormat> _decimalFormatters = {};
  static final Map<String, NumberFormat> _compactFormatters = {};

  static void setCurrency(String code) {
    _currencyCode = code.trim().toUpperCase();
  }

  static String get currencyCode => _currencyCode;

  static String symbol({String? currencyCode}) {
    final code = (currencyCode ?? _currencyCode).toUpperCase();
    return _currencySymbol(code);
  }

  static String format(
    double amount, {
    bool showDecimals = false,
    String? currencyCode,
  }) {
    final code = (currencyCode ?? _currencyCode).toUpperCase();
    final formatter = _resolveFormatter(code, showDecimals);
    return formatter.format(amount);
  }

  static String compact(double amount, {String? currencyCode}) {
    final code = (currencyCode ?? _currencyCode).toUpperCase();
    final symbol = _currencySymbol(code);

    if (code == 'INR') {
      if (amount >= 10000000) {
        return '$symbol${(amount / 10000000).toStringAsFixed(1)}Cr';
      }
      if (amount >= 100000) {
        return '$symbol${(amount / 100000).toStringAsFixed(1)}L';
      }
      if (amount >= 1000) {
        return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
      }
      return format(amount, currencyCode: code);
    }

    final formatter = _compactFormatters.putIfAbsent(code, () {
      return NumberFormat.compactCurrency(
        locale: _currencyLocale(code),
        symbol: symbol,
        decimalDigits: 1,
      );
    });
    return formatter.format(amount);
  }

  static String withSign(
    double amount, {
    bool showDecimals = false,
    String? currencyCode,
  }) {
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
