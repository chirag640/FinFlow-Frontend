import 'package:finflow/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.passwordStrong', () {
    test('rejects missing lowercase character', () {
      expect(
        Validators.passwordStrong('PASSWORD1'),
        'Include at least one lowercase letter',
      );
    });

    test('rejects missing uppercase character', () {
      expect(
        Validators.passwordStrong('password1'),
        'Include at least one uppercase letter',
      );
    });

    test('rejects missing numeric character', () {
      expect(
        Validators.passwordStrong('Password'),
        'Include at least one number',
      );
    });

    test('accepts strong password', () {
      expect(Validators.passwordStrong('Passw0rd'), isNull);
    });
  });
}
