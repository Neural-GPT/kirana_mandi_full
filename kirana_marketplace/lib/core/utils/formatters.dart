import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _rupee = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String rupees(num value) => _rupee.format(value);

  static String km(num value) {
    if (value == value.roundToDouble()) return '${value.toInt()} km';
    return '$value km';
  }
}
