import 'package:aalumai/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('converts rupees to paise without floating point drift', () {
      expect(Money.rupeesToPaise(12.5), 1250);
      expect(Money.rupeesToPaise(0), 0);
      expect(Money.rupeesToPaise(19.99), 1999);
    });

    test('converts paise to rupees', () {
      expect(Money.paiseToRupees(1250), 12.5);
      expect(Money.paiseToRupees(0), 0);
    });

    test('formatCompact renders integer rupees with symbol', () {
      expect(Money.formatCompact(100000), '₹1,000');
    });

    test('format renders two decimal places', () {
      expect(Money.format(12345), contains('123.45'));
    });
  });
}
