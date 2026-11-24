import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/utils/pnl.dart';

void main() {
  group('PnL Utilities', () {
    test('computePnl Buy', () {
      final pnl = computePnl(
        type: 'Buy',
        entryPrice: 100,
        currentPrice: 110,
        amount: 2,
      );
      expect(pnl, equals(20.0));
    });

    test('computePnl Sell', () {
      final pnl = computePnl(
        type: 'Sell',
        entryPrice: 100,
        currentPrice: 110,
        amount: 2,
      );
      expect(pnl, equals(-20.0));
    });

    test("computePnl throws ArgumentError for type 'Hold'", () {
      expect(
        () => computePnl(
          type: 'Hold',
          entryPrice: 100,
          currentPrice: 110,
          amount: 2,
        ),
        throwsArgumentError,
      );
    });

    test('roundTo closeTo and zero check', () {
      expect(roundTo(1.234567891, 8), closeTo(1.23456789, 1e-12));
      expect(roundTo(0.000000004, 8), equals(0.0));
    });

    test('tradeLabel mappings', () {
      expect(tradeLabel('Buy'), equals('Long'));
      expect(tradeLabel('Sell'), equals('Short'));
    });

    test('isLiquidated for Sell', () {
      final isLiqAt200 = isLiquidated(
        type: 'Sell',
        entryPrice: 100,
        currentPrice: 200,
        amount: 2,
        cost: 200,
      );
      expect(isLiqAt200, isTrue);

      final isLiqAt199 = isLiquidated(
        type: 'Sell',
        entryPrice: 100,
        currentPrice: 199,
        amount: 2,
        cost: 200,
      );
      expect(isLiqAt199, isFalse);
    });

    test('isLiquidated for Buy is false even at price 0.01', () {
      final isLiq = isLiquidated(
        type: 'Buy',
        entryPrice: 100,
        currentPrice: 0.01,
        amount: 2,
        cost: 200,
      );
      expect(isLiq, isFalse);
    });
  });
}
