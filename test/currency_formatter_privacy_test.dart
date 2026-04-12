import 'package:finflow/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CurrencyFormatter.setPrivacyMode(false);
    CurrencyFormatter.setCurrency('INR');
  });

  test('masks formatted values when privacy mode is enabled', () {
    CurrencyFormatter.setCurrency('INR');
    CurrencyFormatter.setPrivacyMode(true);

    expect(CurrencyFormatter.format(1543), '₹••••');
    expect(CurrencyFormatter.compact(150000), '₹••••');
    expect(CurrencyFormatter.withSign(-250), '-₹••••');
  });

  test('returns actual formatted value when privacy mode is disabled', () {
    CurrencyFormatter.setCurrency('USD');
    CurrencyFormatter.setPrivacyMode(false);

    expect(CurrencyFormatter.format(1200), '\$1,200');
  });
}
