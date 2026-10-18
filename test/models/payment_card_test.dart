import 'package:flutter_test/flutter_test.dart';
import 'package:multisynk/models/payment_card.dart';
import 'package:multisynk/models/transaction.dart';
import 'package:multisynk/providers/payment_card_provider.dart';

PaymentCard card({int closing = 5, int due = 12}) =>
    PaymentCard(id: 'nubank', name: 'Nubank', closingDay: closing, dueDay: due);

Transaction buy(String id, double amount, DateTime date, {String cardId = 'nubank', TransactionType type = TransactionType.expense}) =>
    Transaction(id: id, description: id, amount: amount, type: type, date: date, cardId: cardId, paymentMethod: PaymentMethod.credit);

void main() {
  group('billing cycle', () {
    test('before closing: cycle runs from the day after last closing through the whole closing day', () {
      final c = card(closing: 5).cycleAt(DateTime(2026, 10, 3, 9));
      expect(c.start, DateTime(2026, 9, 6));
      expect(c.end, DateTime(2026, 10, 6)); // exclusive
    });

    test('on the closing day the purchase still belongs to the closing cycle', () {
      final c = card(closing: 5).cycleAt(DateTime(2026, 10, 5, 22));
      expect(c.start, DateTime(2026, 9, 6));
      expect(c.end, DateTime(2026, 10, 6));
    });

    test('after closing: the next cycle', () {
      final c = card(closing: 5).cycleAt(DateTime(2026, 10, 6, 0, 1));
      expect(c.start, DateTime(2026, 10, 6));
      expect(c.end, DateTime(2026, 11, 6));
    });

    test('closing day 31 clamps to short months', () {
      final feb = card(closing: 31).cycleAt(DateTime(2026, 2, 10));
      expect(feb.start, DateTime(2026, 2, 1));
      expect(feb.end, DateTime(2026, 3, 1)); // closes Feb 28
      final apr = card(closing: 31).cycleAt(DateTime(2026, 4, 30, 18));
      expect(apr.start, DateTime(2026, 4, 1));
      expect(apr.end, DateTime(2026, 5, 1)); // closes Apr 30
    });

    test('year boundary', () {
      final c = card(closing: 10).cycleAt(DateTime(2026, 12, 20));
      expect(c.start, DateTime(2026, 12, 11));
      expect(c.end, DateTime(2027, 1, 11));
      final jan = card(closing: 10).cycleAt(DateTime(2027, 1, 5));
      expect(jan.start, DateTime(2026, 12, 11));
    });

    test('consecutive cycles never overlap nor leave gaps', () {
      final k = card(closing: 30);
      var day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        final c = k.cycleAt(day);
        expect(!day.isBefore(c.start) && day.isBefore(c.end), isTrue, reason: '$day not in $c');
        day = day.add(const Duration(days: 1));
      }
    });
  });

  group('cardCycleTotal', () {
    final now = DateTime(2026, 10, 5, 23, 59);
    final txs = [
      buy('first-day', 10, DateTime(2026, 9, 6, 0, 0)),
      buy('closing-day-afternoon', 20.55, DateTime(2026, 10, 5, 14, 30)),
      buy('previous-cycle', 999, DateTime(2026, 9, 5, 23, 59)),
      buy('next-cycle', 999, DateTime(2026, 10, 6)),
      buy('other-card', 999, DateTime(2026, 10, 1), cardId: 'itau'),
      buy('refund-income', 999, DateTime(2026, 10, 1), type: TransactionType.income),
    ];

    test('includes purchases made on the closing day (was lost before)', () {
      expect(cardCycleTotal(card(closing: 5), txs, now: now), 30.55);
    });
  });

  group('due date', () {
    test('due today counts as today, not next month', () {
      final k = card(due: 12);
      expect(k.nextDueDateAt(DateTime(2026, 10, 12, 18)), DateTime(2026, 10, 12));
      expect(k.daysUntilDueAt(DateTime(2026, 10, 12, 18)), 0);
    });

    test('after due day moves to next month', () {
      final k = card(due: 12);
      expect(k.nextDueDateAt(DateTime(2026, 10, 13)), DateTime(2026, 11, 12));
      expect(k.daysUntilDueAt(DateTime(2026, 10, 13)), 30);
    });

    test('due day 31 clamps (February)', () {
      final k = card(due: 31);
      expect(k.nextDueDateAt(DateTime(2026, 2, 3)), DateTime(2026, 2, 28));
      expect(k.nextDueDateAt(DateTime(2026, 1, 31, 23)), DateTime(2026, 1, 31));
    });

    test('December rolls into January', () {
      expect(card(due: 5).nextDueDateAt(DateTime(2026, 12, 20)), DateTime(2027, 1, 5));
    });
  });
}
