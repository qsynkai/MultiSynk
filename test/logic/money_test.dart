import 'package:flutter_test/flutter_test.dart';
import 'package:multisynk/logic/money.dart';

void main() {
  group('parseMoney', () {
    test('Brazilian formats', () {
      expect(parseMoney('1234,56'), 1234.56);
      expect(parseMoney('1.234,56'), 1234.56);
      expect(parseMoney('1.234.567,89'), 1234567.89);
      expect(parseMoney('R\$ 50'), 50);
      expect(parseMoney(' 0,99 '), 0.99);
      expect(parseMoney('1.500'), 1500);
    });

    test('dot as decimal separator', () {
      expect(parseMoney('12.5'), 12.5);
      expect(parseMoney('12.50'), 12.5);
    });

    test('rounds to cents', () {
      expect(parseMoney('10,999'), 11.0);
      expect(parseMoney('10,994'), 10.99);
    });

    test('rejects empty, zero, negative and garbage', () {
      for (final s in ['', '   ', '0', '0,00', '-5', 'abc', '1,2,3', 'R\$']) {
        expect(parseMoney(s), isNull, reason: s);
      }
    });
  });

  group('splitInstallments', () {
    test('sums exactly to the total, to the cent', () {
      for (final total in [100.0, 99.99, 0.05, 1234.56, 1000.01]) {
        for (var n = 1; n <= 24; n++) {
          final parts = splitInstallments(total, n);
          expect(parts.length, n);
          final cents = parts.fold<int>(0, (s, p) => s + (p * 100).round());
          expect(cents, (total * 100).round(), reason: '$total / $n');
          expect(parts.reduce((a, b) => a > b ? a : b) - parts.reduce((a, b) => a < b ? a : b),
              lessThanOrEqualTo(0.0100001));
        }
      }
    });

    test('remainder goes to the first installments', () {
      expect(splitInstallments(100, 3), [33.34, 33.33, 33.33]);
      expect(splitInstallments(10, 4), [2.5, 2.5, 2.5, 2.5]);
    });

    test('rejects zero installments', () {
      expect(() => splitInstallments(10, 0), throwsArgumentError);
    });
  });

  group('addMonthsClamped', () {
    test('clamps to the last day of shorter months', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonthsClamped(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
      expect(addMonthsClamped(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    });

    test('crosses years and keeps the time', () {
      expect(addMonthsClamped(DateTime(2026, 11, 15, 14, 30), 3), DateTime(2027, 2, 15, 14, 30));
      expect(addMonthsClamped(DateTime(2026, 5, 10), 0), DateTime(2026, 5, 10));
    });

    test('a 12x purchase on day 31 hits every month exactly once', () {
      final start = DateTime(2026, 1, 31);
      final months = [for (var i = 0; i < 12; i++) addMonthsClamped(start, i)];
      expect(months.map((d) => d.month).toList(), List.generate(12, (i) => i + 1));
    });
  });

  test('daysInMonth', () {
    expect(daysInMonth(2026, 2), 28);
    expect(daysInMonth(2028, 2), 29);
    expect(daysInMonth(2026, 12), 31);
    expect(daysInMonth(2026, 4), 30);
  });
}
