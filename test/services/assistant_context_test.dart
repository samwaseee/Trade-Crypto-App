import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/Services/assistant_service.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';

CoinModel _coin(String id, String sym, double price, int rank) => CoinModel(
      id: id,
      symbol: sym,
      name: id,
      image: '',
      currentPrice: price,
      marketCapRank: rank,
      totalVolume: 0,
      high24H: price * 1.1,
      low24H: price * 0.9,
      priceChange24H: 0,
      priceChangePercentage24h: 2.5,
      marketCapChangePercentage24H: 0,
      sparklineIn7D: SparklineIn7D(price: const []),
    );

void main() {
  test('context lists cash, positions with P/L and top coins', () {
    final tx = PortfolioTransaction(
      id: '1',
      type: 'Sell',
      coinId: 'bitcoin',
      amount: 0.5,
      entryPrice: 100000,
      cost: 50000,
      date: DateTime(2026, 1, 1),
    ).withMarketPrice(90000);

    final out = buildAssistantContext(
      wallet: const PortfolioWallet(exists: true, walletUsd: 1234.5),
      transactions: [tx],
      coins: [_coin('ethereum', 'eth', 3000, 2), _coin('bitcoin', 'btc', 90000, 1)],
    );

    expect(out, contains('Cash balance: \$1,234.50'));
    expect(out, contains('bitcoin (BTC) short'));
    expect(out, contains('unrealized P/L'));
    expect(out.indexOf('BTC'), lessThan(out.lastIndexOf('ETH')));
  });

  test('context handles empty portfolio', () {
    final out = buildAssistantContext(
      wallet: const PortfolioWallet(exists: true, walletUsd: 0),
      transactions: const [],
      coins: const [],
    );
    expect(out, contains('Open positions: none'));
  });
}
