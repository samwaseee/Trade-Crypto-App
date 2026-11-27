import 'dart:math' as math;

class MacdResult {
  const MacdResult({
    required this.line,
    required this.signal,
    required this.histogram,
  });

  final double line;
  final double signal;
  final double histogram;
}

class BollingerBands {
  const BollingerBands({
    required this.middle,
    required this.upper,
    required this.lower,
  });

  final double middle;
  final double upper;
  final double lower;
}

List<double> _validPrices(List<double> values) =>
    values.where((value) => value.isFinite && value > 0).toList();

double? sma(List<double> values, int period) {
  if (period <= 0) return null;
  final prices = _validPrices(values);
  if (prices.length < period) return null;

  final window = prices.skip(prices.length - period);
  return window.reduce((sum, value) => sum + value) / period;
}

double? ema(List<double> values, int period) {
  if (period <= 0) return null;
  return _emaFromValues(_validPrices(values), period);
}

double? _emaFromValues(List<double> values, int period) {
  final series = values.where((value) => value.isFinite).toList();
  if (period <= 0 || series.length < period) return null;
  final alpha = 2 / (period + 1);
  var result = series.take(period).reduce((sum, value) => sum + value) / period;
  for (final price in series.skip(period)) {
    result = (price - result) * alpha + result;
  }
  return result;
}

double? rsi(List<double> values, {int period = 14}) {
  if (period <= 0) return null;
  final prices = _validPrices(values);
  if (prices.length <= period) return null;

  var averageGain = 0.0;
  var averageLoss = 0.0;
  for (var index = 1; index <= period; index++) {
    final change = prices[index] - prices[index - 1];
    if (change > 0) {
      averageGain += change;
    } else {
      averageLoss -= change;
    }
  }
  averageGain /= period;
  averageLoss /= period;

  for (var index = period + 1; index < prices.length; index++) {
    final change = prices[index] - prices[index - 1];
    final gain = change > 0 ? change : 0.0;
    final loss = change < 0 ? -change : 0.0;
    averageGain = (averageGain * (period - 1) + gain) / period;
    averageLoss = (averageLoss * (period - 1) + loss) / period;
  }

  if (averageGain == 0 && averageLoss == 0) return 50;
  if (averageLoss == 0) return 100;
  if (averageGain == 0) return 0;

  final relativeStrength = averageGain / averageLoss;
  return 100 - 100 / (1 + relativeStrength);
}

MacdResult? macd(
  List<double> values, {
  int fastPeriod = 12,
  int slowPeriod = 26,
  int signalPeriod = 9,
}) {
  if (fastPeriod <= 0 || slowPeriod <= 0 || signalPeriod <= 0) return null;
  if (fastPeriod >= slowPeriod) return null;

  final prices = _validPrices(values);
  if (prices.length < slowPeriod + signalPeriod - 1) return null;

  final fast = _emaAligned(prices, fastPeriod);
  final slow = _emaAligned(prices, slowPeriod);
  final line = <double>[];
  for (var index = 0; index < prices.length; index++) {
    final fastValue = fast[index];
    final slowValue = slow[index];
    if (fastValue != null && slowValue != null) {
      line.add(fastValue - slowValue);
    }
  }

  final signal = _emaFromValues(line, signalPeriod);
  if (line.isEmpty || signal == null) return null;

  final lineValue = line.last;
  return MacdResult(
    line: lineValue,
    signal: signal,
    histogram: lineValue - signal,
  );
}

List<double?> _emaAligned(List<double> values, int period) {
  final result = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length < period) return result;

  final alpha = 2 / (period + 1);
  var current =
      values.take(period).reduce((sum, value) => sum + value) / period;
  result[period - 1] = current;
  for (var index = period; index < values.length; index++) {
    current = (values[index] - current) * alpha + current;
    result[index] = current;
  }
  return result;
}

BollingerBands? bollinger(
  List<double> values, {
  int period = 20,
  double standardDeviations = 2,
}) {
  if (period <= 0 || !standardDeviations.isFinite || standardDeviations < 0) {
    return null;
  }
  final prices = _validPrices(values);
  if (prices.length < period) return null;

  final window = prices.skip(prices.length - period).toList();
  final middle = window.reduce((sum, value) => sum + value) / period;
  final variance = window
          .map((value) => math.pow(value - middle, 2))
          .reduce((sum, value) => sum + value) /
      period;
  final deviation = math.sqrt(variance);
  return BollingerBands(
    middle: middle,
    upper: middle + standardDeviations * deviation,
    lower: middle - standardDeviations * deviation,
  );
}

double? stochasticK(
  List<double> highs,
  List<double> lows,
  List<double> closes, {
  int period = 14,
}) {
  if (period <= 0) return null;
  final length = math.min(highs.length, math.min(lows.length, closes.length));
  final candles = <({double high, double low, double close})>[];

  for (var index = 0; index < length; index++) {
    final high = highs[index];
    final low = lows[index];
    final close = closes[index];
    if (!high.isFinite ||
        !low.isFinite ||
        !close.isFinite ||
        high <= 0 ||
        low <= 0 ||
        close <= 0 ||
        high < low) {
      continue;
    }
    candles.add((high: high, low: low, close: close));
  }
  if (candles.length < period) return null;

  final window = candles.skip(candles.length - period);
  final highest = window.map((candle) => candle.high).reduce(math.max);
  final lowest = window.map((candle) => candle.low).reduce(math.min);
  if (highest == lowest) return 50;

  final value = 100 * (candles.last.close - lowest) / (highest - lowest);
  return value.clamp(0, 100).toDouble();
}

double? momentum(List<double> values, {int period = 10}) {
  if (period <= 0) return null;
  final prices = _validPrices(values);
  if (prices.length <= period) return null;
  return prices.last - prices[prices.length - period - 1];
}

double? roc(List<double> values, {int period = 10}) {
  if (period <= 0) return null;
  final prices = _validPrices(values);
  if (prices.length <= period) return null;
  final base = prices[prices.length - period - 1];
  return (prices.last - base) / base * 100;
}
