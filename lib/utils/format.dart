import 'package:intl/intl.dart';

String formatUsd(num value) {
  if (value.abs() >= 1) {
    final f = NumberFormat('#,##0.00', 'en_US');
    return f.format(value);
  } else {
    final f = NumberFormat('#,##0.00######', 'en_US');
    String formatted = f.format(value);
    if (!formatted.contains('.')) {
      formatted += '.00';
    } else {
      while (formatted.endsWith('0') && formatted.split('.')[1].length > 2) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }
    return formatted;
  }
}

String formatQuantity(num value) =>
    NumberFormat('#,##0.########', 'en_US').format(value);

String formatSignedUsd(num value) {
  if (value.abs() < 0.005) {
    return '\$${formatUsd(0)}';
  }
  final formattedAmount = formatUsd(value.abs());
  if (value > 0) {
    return '+\$$formattedAmount';
  } else {
    return '-\$$formattedAmount';
  }
}
