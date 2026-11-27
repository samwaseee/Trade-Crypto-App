import '../Model/chartModel.dart';
import 'indicators.dart';

enum Vote { bullish, bearish, neutral }

enum TrendOutlook {
  strongBullish,
  bullish,
  mixed,
  bearish,
  strongBearish,
  insufficientData,
}

class IndicatorResult {
  const IndicatorResult({
    required this.name,
    required this.value,
    required this.vote,
  });

  final String name;
  final String value;
  final Vote? vote;
}

class TrendSignal {
  const TrendSignal({
    required this.indicators,
    required this.bullishCount,
    required this.bearishCount,
    required this.validCount,
    required this.outlook,
  });

  final List<IndicatorResult> indicators;
  final int bullishCount;
  final int bearishCount;
  final int validCount;
  final TrendOutlook outlook;
}

String _display(double? value, {String suffix = ''}) =>
    value == null ? 'n/a' : '${value.toStringAsFixed(2)}$suffix';

Vote comparisonVote(double a, double b) {
  if (a > b) return Vote.bullish;
  if (a < b) return Vote.bearish;
  return Vote.neutral;
}

Vote rsiVote(double value) {
  if (value < 30) return Vote.bullish;
  if (value > 70) return Vote.bearish;
  return Vote.neutral;
}

Vote stochasticVote(double value) {
  if (value < 20) return Vote.bullish;
  if (value > 80) return Vote.bearish;
  return Vote.neutral;
}

Vote bollingerVote(double close, double lower, double upper) {
  if (close < lower) return Vote.bullish;
  if (close > upper) return Vote.bearish;
  return Vote.neutral;
}

Vote momentumVote(double value) {
  if (value > 0) return Vote.bullish;
  if (value < 0) return Vote.bearish;
  return Vote.neutral;
}

Vote? _optionalComparisonVote(double? left, double? right) {
  if (left == null || right == null) return null;
  return comparisonVote(left, right);
}

TrendOutlook classifyTrendOutlook({
  required int bullishCount,
  required int bearishCount,
  required int validCount,
}) {
  if (validCount < 4) return TrendOutlook.insufficientData;
  if (bullishCount * 100 >= validCount * 80) {
    return TrendOutlook.strongBullish;
  }
  if (bullishCount * 100 >= validCount * 60) return TrendOutlook.bullish;
  if (bearishCount * 100 >= validCount * 80) {
    return TrendOutlook.strongBearish;
  }
  if (bearishCount * 100 >= validCount * 60) return TrendOutlook.bearish;
  return TrendOutlook.mixed;
}

TrendSignal computeTrendSignal(List<ChartModel> chartData) {
  final candles = chartData.where((candle) {
    final close = candle.close;
    return close != null && close.isFinite && close > 0;
  }).toList();
  final closes = candles.map((candle) => candle.close!).toList();

  final shortSma = sma(closes, 10);
  final longSma = sma(closes, 30);
  final currentClose = closes.isEmpty ? null : closes.last;
  final currentEma = ema(closes, 20);
  final currentRsi = rsi(closes);
  final currentMacd = macd(closes);
  final bands = bollinger(closes);
  final stochastic = stochasticK(
    candles.map((candle) => candle.high ?? double.nan).toList(),
    candles.map((candle) => candle.low ?? double.nan).toList(),
    closes,
  );
  final currentRoc = roc(closes);

  final results = <IndicatorResult>[
    IndicatorResult(
      name: 'SMA (10/30)',
      value: '${_display(shortSma)} / ${_display(longSma)}',
      vote: _optionalComparisonVote(shortSma, longSma),
    ),
    IndicatorResult(
      name: 'Close / EMA (20)',
      value: '${_display(currentClose)} / ${_display(currentEma)}',
      vote: _optionalComparisonVote(currentClose, currentEma),
    ),
    IndicatorResult(
      name: 'RSI (14)',
      value: _display(currentRsi),
      vote: currentRsi == null ? null : rsiVote(currentRsi),
    ),
    IndicatorResult(
      name: 'MACD (12,26,9)',
      value: currentMacd == null
          ? 'n/a'
          : '${_display(currentMacd.line)} / ${_display(currentMacd.signal)}',
      vote: currentMacd == null
          ? null
          : comparisonVote(currentMacd.line, currentMacd.signal),
    ),
    IndicatorResult(
      name: 'Bollinger (20,2)',
      value: bands == null || currentClose == null
          ? 'n/a'
          : '${_display(currentClose)} [${_display(bands.lower)}, ${_display(bands.upper)}]',
      vote: bands == null || currentClose == null
          ? null
          : bollingerVote(currentClose, bands.lower, bands.upper),
    ),
    IndicatorResult(
      name: 'Stochastic %K (14)',
      value: _display(stochastic, suffix: '%'),
      vote: stochastic == null ? null : stochasticVote(stochastic),
    ),
    IndicatorResult(
      name: 'Momentum (10)',
      value: _display(currentRoc, suffix: '% ROC'),
      vote: currentRoc == null ? null : momentumVote(currentRoc),
    ),
  ];

  final bullishCount =
      results.where((result) => result.vote == Vote.bullish).length;
  final bearishCount =
      results.where((result) => result.vote == Vote.bearish).length;
  final validCount = results.where((result) => result.vote != null).length;

  return TrendSignal(
    indicators: List.unmodifiable(results),
    bullishCount: bullishCount,
    bearishCount: bearishCount,
    validCount: validCount,
    outlook: classifyTrendOutlook(
      bullishCount: bullishCount,
      bearishCount: bearishCount,
      validCount: validCount,
    ),
  );
}
