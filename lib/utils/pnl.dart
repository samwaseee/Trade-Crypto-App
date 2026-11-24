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

double roundMoney(double v) => (v * 100).roundToDouble() / 100;
