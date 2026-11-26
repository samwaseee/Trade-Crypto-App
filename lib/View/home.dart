import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/Model/watchlist_coin.dart';
import 'package:my_crypto/Services/market_repository.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';
import 'package:my_crypto/Services/trade_service.dart';
import 'package:my_crypto/Services/watchlist_repository.dart';
import 'package:my_crypto/View/Components/coin_search_list.dart';
import 'package:my_crypto/View/Components/coin_tile.dart';
import 'package:my_crypto/View/Components/item.dart';
import 'package:my_crypto/View/Components/item2.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:my_crypto/View/asset_detail_screen.dart';
import 'package:my_crypto/View/selectCoin.dart';
import 'package:my_crypto/View/trade_history_screen.dart';
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
  final WatchlistRepository _watchlistRepository = WatchlistRepository.instance;
  late final String userId;
  bool isRefreshing = true;
  late Stream<PortfolioSnapshot> _portfolioStream;
  StreamSubscription<List<WatchlistCoin>>? _watchlistSubscription;
  List<WatchlistCoin> _watchlistCoins = [];
  final Set<String> _pendingWatchlistIds = {};
  bool _isWatchlistLoading = true;
  Object? _watchlistError;
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
    _subscribeToWatchlist();
  }

  void _resubscribePortfolio() {
    setState(() {
      _portfolioStream = _portfolioRepository.portfolioStream(userId);
    });
  }

  @override
  void dispose() {
    unawaited(_watchlistSubscription?.cancel());
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
                children: [
                  const Text(
                    'Assets',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TradeHistoryScreen(userId: userId),
                        ),
                      );
                    },
                    child: const Text('History'),
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
            _buildWatchlistSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Watchlist',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        if (_isWatchlistLoading)
          const CoinListSkeleton(count: 2)
        else if (_watchlistError != null)
          SizedBox(
            height: 180,
            child: ErrorState(
              error: _watchlistError,
              message:
                  'Could not load your watchlist. Check your connection and try again.',
              onRetry: _retryWatchlist,
            ),
          )
        else if (_watchlistCoins.isEmpty)
          const EmptyState(
            message: 'Star a coin in Top 10 coins to add it to your watchlist.',
            icon: Icons.star_outline,
          )
        else
          ..._watchlistCoins.map(_buildWatchlistCoinTile),
      ],
    );
  }

  Widget _buildWatchlistCoinTile(WatchlistCoin entry) {
    final marketCoin = _findMarketCoin(entry.id);
    if (marketCoin != null) {
      return CoinTile(
        coin: marketCoin,
        margin: const EdgeInsets.symmetric(vertical: 6),
        isWatchlisted: true,
        isWatchlistLoading: _pendingWatchlistIds.contains(entry.id),
        onWatchlistTap: _canManageWatchlist
            ? () => _removeWatchlistCoin(entry.id)
            : null,
      );
    }

    final isPending = _pendingWatchlistIds.contains(entry.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: SizedBox(
          width: 36,
          height: 36,
          child: entry.image.isEmpty
              ? const Icon(Icons.currency_bitcoin)
              : Image.network(
                  entry.image,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.currency_bitcoin),
                ),
        ),
        title: Text(entry.name),
        subtitle: Text(entry.symbol.toUpperCase()),
        trailing: IconButton(
          tooltip: 'Remove from watchlist',
          onPressed: !_canManageWatchlist || isPending
              ? null
              : () => _removeWatchlistCoin(entry.id),
          icon: Icon(
            Icons.star,
            color: Theme.of(context).colorScheme.accent,
          ),
        ),
      ),
    );
  }

  CoinModel? _findMarketCoin(String coinId) {
    for (final coin in coinMarket ?? const <dynamic>[]) {
      if (coin is CoinModel && coin.id == coinId) return coin;
    }
    return null;
  }

  bool get _canManageWatchlist =>
      !_isWatchlistLoading && _watchlistError == null;

  void _subscribeToWatchlist() {
    unawaited(_watchlistSubscription?.cancel());
    _watchlistSubscription = _watchlistRepository
        .watchlistStream(userId)
        .listen(
      (coins) {
        if (!mounted) return;
        setState(() {
          _watchlistCoins = coins;
          _isWatchlistLoading = false;
          _watchlistError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isWatchlistLoading = false;
          _watchlistError = error;
        });
      },
    );
  }

  void _retryWatchlist() {
    setState(() {
      _isWatchlistLoading = true;
      _watchlistError = null;
    });
    _subscribeToWatchlist();
  }

  Future<void> _toggleWatchlist(CoinModel coin) async {
    final isWatchlisted = _watchlistCoins.any((entry) => entry.id == coin.id);
    final watchlistCoin = WatchlistCoin(
      id: coin.id,
      name: coin.name,
      symbol: coin.symbol,
      image: coin.image,
    );
    await _updateWatchlist(
      coin.id,
      shouldBeWatchlisted: !isWatchlisted,
      coin: watchlistCoin,
      update: () async {
        if (isWatchlisted) {
          await _watchlistRepository.removeCoin(userId, coin.id);
        } else {
          await _watchlistRepository.addCoin(userId, watchlistCoin);
        }
      },
    );
  }

  Future<void> _removeWatchlistCoin(String coinId) {
    return _updateWatchlist(
      coinId,
      shouldBeWatchlisted: false,
      update: () => _watchlistRepository.removeCoin(userId, coinId),
    );
  }

  Future<void> _updateWatchlist(
    String coinId, {
    required bool shouldBeWatchlisted,
    WatchlistCoin? coin,
    required Future<void> Function() update,
  }) async {
    if (!_canManageWatchlist || _pendingWatchlistIds.contains(coinId)) return;

    WatchlistCoin? previousCoin;
    for (final entry in _watchlistCoins) {
      if (entry.id == coinId) {
        previousCoin = entry;
        break;
      }
    }

    setState(() {
      _pendingWatchlistIds.add(coinId);
      _watchlistCoins = _watchlistCoins
          .where((entry) => entry.id != coinId)
          .toList();
      if (shouldBeWatchlisted && coin != null) {
        _watchlistCoins.add(coin);
      }
    });

    try {
      await update().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Firestore may still complete this queued write after reconnecting.
    } catch (error) {
      if (mounted) {
        setState(() {
          _watchlistCoins = _watchlistCoins
              .where((entry) => entry.id != coinId)
              .toList();
          if (previousCoin != null) _watchlistCoins.add(previousCoin);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update your watchlist. Check your connection and retry. ($error)',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingWatchlistIds.remove(coinId));
    }
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

    return CoinSearchList(
      marketCoins: limitedTop10,
      search: MarketRepository.instance.searchCoins,
      onRefresh: () => getCoinMarket(force: true),
      coinTileBuilder: (coin) => CoinTile(
        coin: coin,
        rank: coin.marketCapRank,
        isWatchlisted: _watchlistCoins.any((entry) => entry.id == coin.id),
        isWatchlistLoading: _pendingWatchlistIds.contains(coin.id),
        onWatchlistTap:
            _canManageWatchlist ? () => _toggleWatchlist(coin) : null,
      ),
      onResultSelected: (result) {
        final coin = _findMarketCoin(result.id) ?? result.toCoinModel();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SelectCoin(selectItem: coin)),
        );
      },
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
          ...topGainers.map(
            (coin) => CoinTile(
              coin: coin,
              isWatchlisted:
                  _watchlistCoins.any((entry) => entry.id == coin.id),
              isWatchlistLoading: _pendingWatchlistIds.contains(coin.id),
              onWatchlistTap: _canManageWatchlist
                  ? () => _toggleWatchlist(coin)
                  : null,
            ),
          ),
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
          ...topLosers.map(
            (coin) => CoinTile(
              coin: coin,
              isWatchlisted:
                  _watchlistCoins.any((entry) => entry.id == coin.id),
              isWatchlistLoading: _pendingWatchlistIds.contains(coin.id),
              onWatchlistTap: _canManageWatchlist
                  ? () => _toggleWatchlist(coin)
                  : null,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<CoinModel>? coinMarket = [];
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
                coinName: coinData.name,
                coinSymbol: coinData.symbol,
                coinImage: coinData.image,
                closeReason: 'liquidated',
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
