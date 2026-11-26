import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';
import 'package:my_crypto/utils/trade_history.dart';

void main() {
  ClosedTrade trade(double realizedPnl) => ClosedTrade(
        id: 'trade',
        type: 'Buy',
        coinId: 'bitcoin',
        coinName: 'Bitcoin',
        coinSymbol: 'btc',
        coinImage: '',
        amount: 1,
        entryPrice: 100,
        exitPrice: 110,
        cost: 100,
        realizedPnl: realizedPnl,
        closeReason: 'manual',
        openedAt: DateTime(2026),
        closedAt: DateTime(2026),
      );

  test('summarizeClosedTrades handles empty history', () {
    final summary = summarizeClosedTrades([]);

    expect(summary.totalRealizedPnl, 0);
    expect(summary.tradeCount, 0);
    expect(summary.winCount, 0);
    expect(summary.winRate, 0);
  });

  test('summarizeClosedTrades counts positive trades as wins', () {
    final summary = summarizeClosedTrades([
      trade(10),
      trade(-5),
      trade(0),
    ]);

    expect(summary.totalRealizedPnl, 5);
    expect(summary.tradeCount, 3);
    expect(summary.winCount, 1);
    expect(summary.winRate, closeTo(1 / 3, 0.000001));
  });
}
