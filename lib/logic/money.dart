/// Parses a value typed in Brazilian format ("1.234,56", "1234,56", "R$ 50", "12.5").
/// Returns null for empty, unparseable, non-finite or non-positive input.
double? parseMoney(String input) {
  var s = input.replaceAll(RegExp(r'[R$\s]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    // Comma is the decimal separator; dots are thousand separators.
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    // "1.234" or "1.234.567" without comma: dots are thousand separators.
    s = s.replaceAll('.', '');
  }
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || v <= 0) return null;
  return roundCents(v);
}

double roundCents(double v) => (v * 100).roundToDouble() / 100;

/// Splits [total] into [count] installments that add up exactly to the cent.
/// The remainder cents go to the first installments (e.g. 100 / 3 → 33.34, 33.33, 33.33).
List<double> splitInstallments(double total, int count) {
  if (count < 1) throw ArgumentError.value(count, 'count', 'must be >= 1');
  final totalCents = (total * 100).round();
  final base = totalCents ~/ count;
  final remainder = totalCents % count;
  return List.generate(count, (i) => (base + (i < remainder ? 1 : 0)) / 100);
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Same day [months] later, clamped to the last day of the target month
/// (Jan 31 + 1 month → Feb 28/29, never Mar 3).
DateTime addMonthsClamped(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months, 1);
  final day = date.day.clamp(1, daysInMonth(first.year, first.month));
  return DateTime(first.year, first.month, day, date.hour, date.minute, date.second, date.millisecond);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
