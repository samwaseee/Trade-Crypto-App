import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/utils/indicators.dart';

void main() {
  group('moving averages', () {
    test('SMA and EMA use the latest period values', () {
      expect(sma([1, 2, 3, 4, 5], 3), 4);
      expect(ema([1, 2, 3, 4, 5], 3), 4);
    });

    test('invalid prices are skipped', () {
      expect(sma([1, double.nan, -2, 5], 2), 3);
    });
  });

  group('RSI', () {
    test('returns the expected values for rising, falling, and flat series',
        () {
      expect(rsi(List.generate(15, (index) => 100.0 + index)), 100);
      expect(rsi(List.generate(15, (index) => 100.0 - index)), 0);
      expect(rsi(List.filled(15, 100)), 50);
    });
  });

  test('MACD returns its line, signal, and histogram', () {
    final result = macd(
      [1, 2, 3, 4, 5, 6],
      fastPeriod: 2,
      slowPeriod: 3,
      signalPeriod: 2,
    );

    expect(result, isNotNull);
    expect(result!.line, closeTo(0.5, 1e-10));
    expect(result.signal, closeTo(0.5, 1e-10));
    expect(result.histogram, closeTo(0, 1e-10));
  });

  test('Bollinger bands use population standard deviation', () {
    final result = bollinger([1, 2, 3], period: 3);

    expect(result, isNotNull);
    expect(result!.middle, 2);
    expect(result.upper, closeTo(2 + 2 * math.sqrt(2 / 3), 1e-10));
    expect(result.lower, closeTo(2 - 2 * math.sqrt(2 / 3), 1e-10));
  });

  test('stochastic %K uses the period high and low', () {
    expect(
      stochasticK([10, 12, 13], [5, 7, 9], [7, 11, 10], period: 3),
      62.5,
    );
    expect(
      stochasticK([5, 5, 5], [5, 5, 5], [5, 5, 5], period: 3),
      50,
    );
  });

  test('momentum and ROC compare with the close N periods ago', () {
    expect(momentum([10, 12, 15], period: 2), 5);
    expect(roc([10, 12, 15], period: 2), 50);
  });

  test('returns null when the required history is unavailable', () {
    expect(sma([1, 2], 3), isNull);
    expect(ema([1, 2], 3), isNull);
    expect(rsi(List.filled(14, 1)), isNull);
    expect(macd(List.filled(33, 1)), isNull);
    expect(bollinger(List.filled(19, 1)), isNull);
    expect(stochasticK([1, 2], [1, 2], [1, 2]), isNull);
    expect(momentum(List.filled(10, 1)), isNull);
    expect(roc(List.filled(10, 1)), isNull);
  });
}
