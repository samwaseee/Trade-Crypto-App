import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/Services/market_repository.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';
import 'package:my_crypto/Services/trade_service.dart';
import 'package:my_crypto/View/Components/coin_tile.dart';
import 'package:my_crypto/View/Components/item.dart';
import 'package:my_crypto/View/Components/item2.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:my_crypto/View/asset_detail_screen.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/utils/format.dart';
import 'package:my_crypto/utils/pnl.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final PortfolioRepository _portfolioRepository = PortfolioRepository.instance;
  late final String userId;
  bool isRefreshing = true;
  late Stream<PortfolioSnapshot> _portfolioStream;
  final ValueNotifier<Map<String, double>> _currentPrices = ValueNotifier({});

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Home requires an authenticated user.');
    }
    userId = uid;
    _portfolioStream = _portfolioRepository.portfolioStream(userId);
    getCoinMarket();
  }

  void _resubscribePortfolio() {
    setState(() {
      _portfolioStream = _portfolioRepository.portfolioStream(userId);
    });
  }

  @override
  void dispose() {
    _currentPrices.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text(
            'Trade Crypto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          bottom: TabBar(
            tabs: const [
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Main portfolio'),
                ),
              ),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Top 10 coins'),
                ),
              ),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Experimental'),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPortfolioTab(),
            _buildTop10Tab(),
            _buildExperimentalTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketStateWidget() {
    if (isRefreshing && (coinMarket == null || coinMarket!.isEmpty)) {
      return const CoinListSkeleton(count: 4);
    }
    if (coinMarket == null || coinMarket!.isEmpty) {
      if (_marketError != null) {
        return ErrorState(
          error: _marketError,
          onRetry: () => getCoinMarket(force: true),
        );
      }
      return const EmptyState(message: 'No market data found.');
    }
    return const SizedBox.shrink();
  }

  Widget _buildStateWidgetForTab(BoxConstraints constraints) {
    final stateWidget = _buildMarketStateWidget();
    return RefreshIndicator(
      onRefresh: () => getCoinMarket(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: stateWidget),
        ),
      ),
    );
  }

  Widget _buildPortfolioTab() {
    return RefreshIndicator(
      onRefresh: () => getCoinMarket(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallet Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ValueListenableBuilder<Map<String, double>>(
                  valueListenable: _currentPrices,
                  builder: (context, currentPrices, _) =>
                      StreamBuilder<PortfolioSnapshot>(
                    stream: _portfolioStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const PortfolioHeaderSkeleton();
                      }
                      if (snapshot.hasError) {
                        return ErrorState(
                          error: snapshot.error,
                          onRetry: _resubscribePortfolio,
                        );
                      }
                      if (!snapshot.hasData || !snapshot.data!.wallet.exists) {
                        return const EmptyState(
                            message: 'No wallet data found.');
                      }

                      final portfolio = snapshot.data!;
                      final walletAmount = portfolio.wallet.walletUsd;
                      double inPositions = 0.0;
                      double equityPositions = 0.0;
                      final hasMarketData = currentPrices.isNotEmpty;

                      for (final transaction in portfolio.transactions) {
                        if (transaction.type != 'Buy' &&
                            transaction.type != 'Sell') {
                          continue;
                        }
                        inPositions += transaction.cost;
                        final currentPrice = currentPrices[transaction.coinId];
                        final profit = currentPrice == null
                            ? null
                            : computePnl(
                                type: transaction.type,
                                entryPrice: transaction.entryPrice,
                                currentPrice: currentPrice,
                                amount: transaction.amount,
                              );
                        if (hasMarketData && profit != null) {
                          equityPositions +=
                              max(0.0, transaction.cost + profit);
                        }
                      }

                      final equity = walletAmount + equityPositions;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${formatUsd(walletAmount)}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'In positions: \$${formatUsd(inPositions)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              if (hasMarketData) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Equity: \$${formatUsd(equity)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.accent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                            ),
                            child: Image.asset(
                              'assets/icons/5.1.png',
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Assets Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: const [
                  Text(
                    'Assets',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Assets Content Area
            if (isRefreshing && (coinMarket == null || coinMarket!.isEmpty))
              const SizedBox(height: 300, child: CoinListSkeleton(count: 3))
            else if (coinMarket == null || coinMarket!.isEmpty)
              _marketError != null
                  ? ErrorState(
                      error: _marketError,
                      onRetry: () => getCoinMarket(force: true),
                    )
                  : const EmptyState(message: 'No market data found.')
            else
              StreamBuilder<PortfolioSnapshot>(
                stream: _portfolioStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                        height: 300, child: CoinListSkeleton(count: 3));
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                      error: snapshot.error,
                      onRetry: _resubscribePortfolio,
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.transactions.isEmpty) {
                    return const EmptyState(message: 'No transactions found.');
                  }

                  final userTransactions = [...snapshot.data!.transactions]
                    ..sort((a, b) => b.date.compareTo(a.date));

                  return ListView.builder(
                    itemCount: userTransactions.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final transaction = userTransactions[index];
                      final matchingCoins = coinMarket!
                          .where((coin) => coin.id == transaction.coinId);
                      if (matchingCoins.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final coinData = matchingCoins.first;

                      if (transaction.type != 'Buy' &&
                          transaction.type != 'Sell') {
                        return const SizedBox.shrink();
                      }
                      final transactionData = transaction.toMap();

                      // PnL is computed inside AssetDetailScreen

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssetDetailScreen(
                                coin: coinData,
                                transaction: transactionData,
                              ),
                            ),
                          );
                        },
                        child: Item(
                          item: coinData,
                          transaction: transactionData,
                        ),
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 24),
            // Recommend to Buy Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: const [
                  Text(
                    'Recommend to Buy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Recommend to Buy Content Area
            if (isRefreshing && (coinMarket == null || coinMarket!.isEmpty))
              const SizedBox(
                height: 220,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SkeletonShimmer(height: 200, borderRadius: 20),
                ),
              )
            else if (coinMarket == null || coinMarket!.isEmpty)
              const SizedBox.shrink()
            else
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: coinMarket!.length,
                  itemBuilder: (context, index) {
                    return Item2(
                      item: coinMarket![index],
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTop10Tab() {
    if (coinMarket == null || coinMarket!.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => _buildStateWidgetForTab(constraints),
      );
    }

    final top10Coins = coinMarket!
        .where((coin) => coin.marketCapRank > 0)
        .toList()
      ..sort((a, b) => a.marketCapRank.compareTo(b.marketCapRank));
    final limitedTop10 = top10Coins.take(10).toList();

    return RefreshIndicator(
      onRefresh: () => getCoinMarket(force: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: limitedTop10.length,
        itemBuilder: (context, index) {
          final coin = limitedTop10[index];
          return CoinTile(
            coin: coin,
            rank: coin.marketCapRank,
          );
        },
      ),
    );
  }

  Widget _buildExperimentalTab() {
    if (coinMarket == null || coinMarket!.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => _buildStateWidgetForTab(constraints),
      );
    }

    final sortedByChange = List<CoinModel>.from(coinMarket!)
      ..sort((a, b) =>
          b.priceChangePercentage24h.compareTo(a.priceChangePercentage24h));

    final topGainers = sortedByChange.take(5).toList();
    final topLosers = sortedByChange.reversed.take(5).toList();

    return RefreshIndicator(
      onRefresh: () => getCoinMarket(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Top Gainers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...topGainers.map((coin) => CoinTile(coin: coin)),
          const SizedBox(height: 16),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Top Losers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...topLosers.map((coin) => CoinTile(coin: coin)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List? coinMarket = [];
  List<CoinModel>? coinMarketList;
  MarketException? _marketError;

  Future<void> getCoinMarket({bool force = false}) async {
    setState(() {
      isRefreshing = true;
    });
    try {
      final coins = await MarketRepository.instance.getMarkets(force: force);
      if (!mounted) return;
      setState(() {
        isRefreshing = false;
        coinMarketList = coins;
        coinMarket = coins;
        _marketError = null;
        _currentPrices.value = {
          for (final coin in coins) coin.id: coin.currentPrice,
        };
      });
      if (mounted && coinMarket != null && coinMarket!.isNotEmpty) {
        _checkLiquidations();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isRefreshing = false;
        coinMarket = [];
        _marketError = e is MarketException ? e : BadData();
      });
    }
  }

  bool _liquidating = false;

  Future<void> _checkLiquidations() async {
    if (_liquidating || coinMarket == null || coinMarket!.isEmpty) {
      return;
    }
    _liquidating = true;
    try {
      final transactions =
          await _portfolioRepository.transactionsStream(userId).first;

      final List<String> liquidatedCoins = [];

      for (final transaction in transactions) {
        final type = transaction.type;
        final coinId = transaction.coinId;
        final cost = transaction.cost;

        if (type != 'Sell' || coinId.isEmpty) continue;

        final matchingCoins = coinMarket!.where((coin) => coin.id == coinId);
        if (matchingCoins.isEmpty) continue;
        final coinData = matchingCoins.first;

        final entryPrice = transaction.entryPrice;
        final amount = transaction.amount;
        final currentPrice = coinData.currentPrice;

        if (isLiquidated(
          type: 'Sell',
          entryPrice: entryPrice,
          currentPrice: currentPrice,
          amount: amount,
          cost: cost,
        )) {
          double freshPrice;
          try {
            freshPrice = await MarketRepository.instance
                .getFreshPrice(coinId.toString());
          } catch (_) {
            continue;
          }

          if (isLiquidated(
            type: 'Sell',
            entryPrice: entryPrice,
            currentPrice: freshPrice,
            amount: amount,
            cost: cost,
          )) {
            try {
              await TradeService().closeTrade(
                userId: userId,
                transactionId: transaction.id,
                currentPrice: freshPrice,
              );
              liquidatedCoins.add(coinId.toString());
            } catch (_) {}
          }
        }
      }

      if (liquidatedCoins.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Short on ${liquidatedCoins.join(', ')} was liquidated')),
        );
      }
    } catch (_) {
      // Ignore errors
    } finally {
      _liquidating = false;
    }
  }
}
