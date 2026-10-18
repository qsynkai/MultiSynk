import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../logic/money.dart' show roundCents;
import '../models/payment_card.dart';
import '../models/transaction.dart';

class PaymentCardState {
  final List<PaymentCard> cards;
  final bool isLoading;

  const PaymentCardState({this.cards = const [], this.isLoading = false});

  PaymentCardState copyWith({List<PaymentCard>? cards, bool? isLoading}) =>
      PaymentCardState(cards: cards ?? this.cards, isLoading: isLoading ?? this.isLoading);
}

class PaymentCardNotifier extends StateNotifier<PaymentCardState> {
  PaymentCardNotifier() : super(const PaymentCardState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final cards = await DatabaseHelper.instance.getPaymentCards();
    state = PaymentCardState(cards: cards);
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
