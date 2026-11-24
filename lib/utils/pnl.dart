import 'dart:math';

double computePnl({
  required String type,
  required double entryPrice,
  required double currentPrice,
  required double amount,
}) {
  if (type == 'Buy') {
    return (currentPrice - entryPrice) * amount;
  } else if (type == 'Sell') {
    return (entryPrice - currentPrice) * amount;
  } else {
    throw ArgumentError("Invalid trade type: '$type'. Expected 'Buy' or 'Sell'.");
  }
}

String tradeLabel(String type) {
  if (type == 'Buy') return 'Long';
  if (type == 'Sell') return 'Short';
  return type;
}

double roundMoney(double v) => (v * 100).roundToDouble() / 100;

double roundTo(double v, int decimals) {
  final mod = pow(10, decimals);
  return (v * mod).roundToDouble() / mod;
}
