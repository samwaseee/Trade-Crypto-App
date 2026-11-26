import 'package:my_crypto/Services/portfolio_repository.dart';

class ClosedTradeSummary {
  const ClosedTradeSummary({
    required this.totalRealizedPnl,
    required this.tradeCount,
    required this.winCount,
    required this.winRate,
  });

  final double totalRealizedPnl;
  final int tradeCount;
  final int winCount;
  final double winRate;
}

ClosedTradeSummary summarizeClosedTrades(List<ClosedTrade> trades) {
  final totalRealizedPnl = trades.fold<double>(
    0,
    (total, trade) => total + trade.realizedPnl,
  );
  final winCount = trades.where((trade) => trade.realizedPnl > 0).length;

  return ClosedTradeSummary(
    totalRealizedPnl: totalRealizedPnl,
    tradeCount: trades.length,
    winCount: winCount,
    winRate: trades.isEmpty ? 0 : winCount / trades.length,
  );
}
