import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/View/Components/coin_tile.dart';
import 'package:my_crypto/View/Components/item2.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/utils/format.dart';

void main() {
  test('formats tiny crypto quantities without rounding to zero', () {
    expect(formatQuantity(1e-8), '0.00000001');
    expect(formatQuantity(0.000001), '0.000001');
    expect(formatQuantity(1.25), '1.25');
  });

  testWidgets('Top 10 loading layout builds without exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 600),
              child: const Center(child: CoinListSkeleton()),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('CoinTile shows and toggles the filled watchlist star',
      (tester) async {
    final coin = CoinModel(
      id: 'bitcoin',
      symbol: 'btc',
      name: 'Bitcoin',
      image: '',
      currentPrice: 67321.45,
      marketCapRank: 1,
      totalVolume: 24300000000,
      high24H: 68000,
      low24H: 65000,
      priceChange24H: 1230,
      priceChangePercentage24h: 5.4,
      marketCapChangePercentage24H: 1.2,
      sparklineIn7D: SparklineIn7D(price: []),
    );
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CoinTile(
            coin: coin,
            isWatchlisted: true,
            onWatchlistTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byTooltip('Remove from watchlist'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from watchlist'));
    expect(tapped, isTrue);
  });

  testWidgets('CoinTile and Item2 fit at large text size', (tester) async {
    final coin = CoinModel(
      id: 'bitcoin',
      symbol: 'btc',
      name: 'Bitcoin',
      image: '',
      currentPrice: 67321.45,
      marketCapRank: 1,
      totalVolume: 24300000000,
      high24H: 68000,
      low24H: 65000,
      priceChange24H: 1230,
      priceChangePercentage24h: 5.4,
      marketCapChangePercentage24H: 1.2,
      sparklineIn7D: SparklineIn7D(price: []),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinTile(coin: coin, rank: 1),
                  Item2(item: coin),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
