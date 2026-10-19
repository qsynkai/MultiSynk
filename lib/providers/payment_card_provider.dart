import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../logic/money.dart' show roundCents;
import '../models/payment_card.dart';
import '../models/card_bill_payment.dart';
import '../models/transaction.dart';

class PaymentCardState {
  final List<PaymentCard> cards;
  final List<CardBillPayment> billPayments;
  final bool isLoading;

  const PaymentCardState({
    this.cards = const [],
    this.billPayments = const [],
    this.isLoading = false,
  });

  bool isBillPaid(String cardId, int year, int month) =>
      billPayments.any((p) => p.cardId == cardId && p.year == year && p.month == month);

  CardBillPayment? billPaymentFor(String cardId, int year, int month) {
    try {
      return billPayments.firstWhere((p) => p.cardId == cardId && p.year == year && p.month == month);
    } catch (_) {
      return null;
    }
  }

  PaymentCardState copyWith({List<PaymentCard>? cards, List<CardBillPayment>? billPayments, bool? isLoading}) =>
      PaymentCardState(
        cards: cards ?? this.cards,
        billPayments: billPayments ?? this.billPayments,
        isLoading: isLoading ?? this.isLoading,
      );
}

class PaymentCardNotifier extends StateNotifier<PaymentCardState> {
  PaymentCardNotifier() : super(const PaymentCardState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final cards = await DatabaseHelper.instance.getPaymentCards();
    final billPayments = await DatabaseHelper.instance.getCardBillPayments();
    state = PaymentCardState(cards: cards, billPayments: billPayments);
  }

  Future<void> add(PaymentCard card) async {
    await DatabaseHelper.instance.insertPaymentCard(card);
    await load();
  }

  Future<void> update(PaymentCard card) async {
    await DatabaseHelper.instance.updatePaymentCard(card);
    await load();
  }

  Future<void> delete(String id) async {
    await DatabaseHelper.instance.deletePaymentCard(id);
    await load();
  }

  Future<void> markBillPaid(String cardId, int year, int month, {double? amount}) async {
    final payment = CardBillPayment(
      id: const Uuid().v4(),
      cardId: cardId,
      year: year,
      month: month,
      amount: amount,
      paidAt: DateTime.now(),
    );
    await DatabaseHelper.instance.upsertCardBillPayment(payment);
    await load();
  }

  Future<void> unmarkBillPaid(String cardId, int year, int month) async {
    await DatabaseHelper.instance.deleteCardBillPayment(cardId, year, month);
    await load();
  }
}

final paymentCardProvider = StateNotifierProvider<PaymentCardNotifier, PaymentCardState>(
  (ref) => PaymentCardNotifier(),
);

/// Total of the card's current billing cycle (cycle end is exclusive).
double cardCycleTotal(PaymentCard card, List<Transaction> transactions, {DateTime? now}) {
  final cycle = card.cycleAt(now ?? DateTime.now());
  return roundCents(transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          t.cardId == card.id &&
          !t.date.isBefore(cycle.start) &&
          t.date.isBefore(cycle.end))
      .fold(0.0, (sum, t) => sum + t.amount));
}

/// Total for a specific billing month (by due month).
double cardMonthTotal(PaymentCard card, List<Transaction> transactions, int year, int month) {
  final cycleRef = DateTime(year, month, card.dueDay);
  final cycle = card.cycleAt(cycleRef);
  return roundCents(transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          t.cardId == card.id &&
          !t.date.isBefore(cycle.start) &&
          t.date.isBefore(cycle.end))
      .fold(0.0, (sum, t) => sum + t.amount));
}
