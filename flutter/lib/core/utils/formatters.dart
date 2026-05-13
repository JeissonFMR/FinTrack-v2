import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String currency(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: symbol,
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String date(DateTime date) =>
      DateFormat('d MMM yyyy', 'es').format(date);

  static String shortDate(DateTime date) =>
      DateFormat('d MMM', 'es').format(date);

  static String monthYear(DateTime date) =>
      DateFormat('MMMM yyyy', 'es').format(date);
}
