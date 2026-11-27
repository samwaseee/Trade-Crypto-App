import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Model/chartModel.dart';
import 'package:my_crypto/utils/trend_signal.dart';

void main() {
  group('pure vote functions at exact boundaries', () {
    test('RSI thresholds are neutral at 30 and 70', () {
      expect(rsiVote(30), Vote.neutral);
      expect(rsiVote(70), Vote.neutral);
      expect(rsiVote(29.999999), Vote.bullish);
      expect(rsiVote(70.000001), Vote.bearish);
    });

    test('stochastic thresholds are neutral at 20 and 80', () {
      expect(stochasticVote(20), Vote.neutral);
      expect(stochasticVote(80), Vote.neutral);
      expect(stochasticVote(19.999999), Vote.bullish);
      expect(stochasticVote(80.000001), Vote.bearish);
    });

    test('Bollinger band equality is neutral', () {
      expect(bollingerVote(10, 10, 20), Vote.neutral);
      expect(bollingerVote(20, 10, 20), Vote.neutral);
      expect(bollingerVote(9.999999, 10, 20), Vote.bullish);
      expect(bollingerVote(20.000001, 10, 20), Vote.bearish);
    });

    test('momentum zero and comparison equality are neutral', () {
      expect(momentumVote(0), Vote.neutral);
      expect(momentumVote(0.000001), Vote.bullish);
      expect(momentumVote(-0.000001), Vote.bearish);
      expect(comparisonVote(10, 10), Vote.neutral);
      expect(comparisonVote(10.000001, 10), Vote.bullish);
      expect(comparisonVote(9.999999, 10), Vote.bearish);
    });
  });

  group('indicator votes', () {
    test('SMA and EMA comparisons vote at equality and on either side', () {
      expect(_result(_chart(_rising(40)), 'SMA (10/30)').vote, Vote.bullish);
      expect(_result(_chart(_falling(40)), 'SMA (10/30)').vote, Vote.bearish);
      expect(_result(_chart(List.filled(40, 100)), 'SMA (10/30)').vote,
          Vote.neutral);

      expect(
          _result(_chart(_rising(40)), 'Close / EMA (20)').vote, Vote.bullish);
      expect(
          _result(_chart(_falling(40)), 'Close / EMA (20)').vote, Vote.bearish);
      expect(_result(_chart(List.filled(40, 100)), 'Close / EMA (20)').vote,
          Vote.neutral);
    });

    test('RSI thresholds are strict and oversold/overbought votes reverse', () {
      expect(_result(_chart(_rising(15)), 'RSI (14)').vote, Vote.bearish);
      expect(_result(_chart(_falling(15)), 'RSI (14)').vote, Vote.bullish);
      expect(
          _result(_chart(_closesForRsi(3, 7)), 'RSI (14)').vote, Vote.neutral);
      expect(
          _result(_chart(_closesForRsi(7, 3)), 'RSI (14)').vote, Vote.neutral);
      expect(
          _result(_chart(List.filled(15, 100)), 'RSI (14)').vote, Vote.neutral);
    });

    test('MACD compares its line with signal', () {
      expect(_result(_chart(_rising(50)), 'MACD (12,26,9)').vote, Vote.bullish);
      expect(
          _result(_chart(_falling(50)), 'MACD (12,26,9)').vote, Vote.bearish);
      expect(_result(_chart(List.filled(50, 100)), 'MACD (12,26,9)').vote,
          Vote.neutral);
    });

    test('Bollinger and stochastic votes are neutral at the band boundaries',
        () {
      expect(_result(_chart(List.filled(20, 100)), 'Bollinger (20,2)').vote,
          Vote.neutral);
      final belowBand = <double>[...List<double>.filled(20, 100), 50];
      final aboveBand = <double>[...List<double>.filled(20, 100), 200];
      expect(_result(_chart(belowBand), 'Bollinger (20,2)').vote, Vote.bullish);
      expect(_result(_chart(aboveBand), 'Bollinger (20,2)').vote, Vote.bearish);

      expect(_result(_stochasticChart(28), 'Stochastic %K (14)').vote,
          Vote.neutral);
      expect(_result(_stochasticChart(82), 'Stochastic %K (14)').vote,
          Vote.neutral);
      expect(_result(_stochasticChart(27), 'Stochastic %K (14)').vote,
          Vote.bullish);
      expect(_result(_stochasticChart(83), 'Stochastic %K (14)').vote,
          Vote.bearish);
    });

    test('momentum votes on positive, negative, and zero change', () {
      expect(_result(_chart(_rising(20)), 'Momentum (10)').vote, Vote.bullish);
      expect(_result(_chart(_falling(20)), 'Momentum (10)').vote, Vote.bearish);
      expect(_result(_chart(List.filled(20, 100)), 'Momentum (10)').vote,
          Vote.neutral);
    });
  });

  group('outlook classification', () {
    test('uses the 60% and 80% thresholds', () {
      expect(
        classifyTrendOutlook(
          bullishCount: 8,
          bearishCount: 0,
          validCount: 10,
        ),
        TrendOutlook.strongBullish,
      );
      expect(
        classifyTrendOutlook(
          bullishCount: 7,
          bearishCount: 0,
          validCount: 10,
        ),
        TrendOutlook.bullish,
      );
      expect(
        classifyTrendOutlook(
          bullishCount: 6,
          bearishCount: 0,
          validCount: 10,
        ),
        TrendOutlook.bullish,
      );
      expect(
        classifyTrendOutlook(
          bullishCount: 5,
          bearishCount: 0,
          validCount: 10,
        ),
        TrendOutlook.mixed,
      );
      expect(
        classifyTrendOutlook(
          bullishCount: 0,
          bearishCount: 6,
          validCount: 10,
        ),
        TrendOutlook.bearish,
      );
      expect(
        classifyTrendOutlook(
          bullishCount: 0,
          bearishCount: 8,
          validCount: 10,
        ),
        TrendOutlook.strongBearish,
      );
    });

    test('skipped indicators are excluded from the vote total', () {
      final signal = computeTrendSignal(_chart(_rising(40)));

      expect(signal.indicators, hasLength(7));
      expect(signal.indicators[5].vote, isNull);
      expect(signal.validCount, 6);
      expect(signal.outlook, isNot(TrendOutlook.insufficientData));
    });

    test('requires four valid indicators and leans with price direction', () {
      expect(computeTrendSignal([]).outlook, TrendOutlook.insufficientData);

      final rising = computeTrendSignal(_chart(_rising(80)));
      final falling = computeTrendSignal(_chart(_falling(80)));
      expect(
        rising.outlook,
        anyOf(TrendOutlook.bullish, TrendOutlook.strongBullish),
      );
      expect(
        falling.outlook,
        anyOf(TrendOutlook.bearish, TrendOutlook.strongBearish),
      );
    });
  });
}

IndicatorResult _result(List<ChartModel> chart, String name) =>
    computeTrendSignal(chart)
        .indicators
        .firstWhere((indicator) => indicator.name == name);

List<ChartModel> _chart(
  List<double> closes, {
  List<double?>? highs,
  List<double?>? lows,
}) =>
    List.generate(
      closes.length,
      (index) => ChartModel(
        time: index * 1000,
        open: closes[index],
        high: highs?[index],
        low: lows?[index],
        close: closes[index],
      ),
    );

List<ChartModel> _stochasticChart(double lastClose) {
  final closes = <double>[...List<double>.filled(13, 50), lastClose];
  final highs = <double?>[...List<double?>.filled(13, 60), null];
  final lows = <double?>[...List<double?>.filled(13, 40), null];
  highs[0] = 100;
  lows[0] = 10;
  highs[13] = lastClose > 50 ? 90 : 40;
  lows[13] = lastClose > 50 ? 80 : 20;
  return _chart(closes, highs: highs, lows: lows);
}

List<double> _closesForRsi(double gain, double loss) {
  final changes = <double>[gain, -loss, ...List<double>.filled(12, 0)];
  var current = 100.0;
  final closes = <double>[current];
  for (final change in changes) {
    current += change;
    closes.add(current);
  }
  return closes;
}

List<double> _rising(int count) =>
    List.generate(count, (index) => 100 + index * 0.5 + index * index * 0.01);

List<double> _falling(int count) =>
    List.generate(count, (index) => 200 - index * 0.5 - index * index * 0.01);
