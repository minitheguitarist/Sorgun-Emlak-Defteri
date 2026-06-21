import 'package:intl/intl.dart';

final _moneyFormatter = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: 'TL',
  decimalDigits: 0,
);

final _dateFormatter = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

String formatMoney(num value) => _moneyFormatter.format(value);

String formatPercent(num value) => '%${value.toStringAsFixed(1)}';

String formatDate(DateTime value) => _dateFormatter.format(value);

String formatArea(num value) {
  final decimalDigits = value % 1 == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimalDigits)} m²';
}

double parseMoneyInput(String value) {
  final cleaned = value
      .replaceAll('TL', '')
      .replaceAll('tl', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9\.-]'), '')
      .trim();
  return double.tryParse(cleaned) ?? 0;
}

double? parseOptionalNumberInput(String value) {
  var cleaned = value.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
  final dotCount = '.'.allMatches(cleaned).length;
  final commaCount = ','.allMatches(cleaned).length;
  if (commaCount > 0) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (dotCount > 1) {
    cleaned = cleaned.replaceAll('.', '');
  }
  if (cleaned.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(cleaned);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}
