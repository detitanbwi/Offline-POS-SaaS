import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(double value) {
    return _rupiahFormat.format(value);
  }

  static String formatNumber(num value) {
    return NumberFormat.decimalPattern('id_ID').format(value);
  }
}
