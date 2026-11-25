import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/View/Components/coin_tile.dart';
import 'package:my_crypto/View/Components/item.dart';
import 'package:my_crypto/View/Components/item2.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Services/market_repository.dart';
import 'package:my_crypto/Services/trade_service.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/utils/format.dart';
import 'package:my_crypto/utils/pnl.dart';

class PortfolioData {
  final DocumentSnapshot walletDoc;
  final List<Map<String, dynamic>> transactions;

  PortfolioData(this.walletDoc, this.transactions);
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isRefreshing = true;
  List? userTransactions = [];

  late final Stream<DocumentSnapshot> _walletStream;
  late final Stream<List<Map<String, dynamic>>> _transactionsStream;
  late final Stream<PortfolioData> _portfolioStream;
  late final Stream<List<Map<String, dynamic>>> _assetsStream;

  @override
  void initState() {
    _walletStream = fetchWalletStream(userId);
    _transactionsStream = fetchUserTransactions(userId);
    _portfolioStream = _combinePortfolioStreams(_walletStream, _transactionsStream);
    _assetsStream = fetchUserTransactions(userId);
    getCoinMarket();
    super.initState();
  }

  Stream<PortfolioData> _combinePortfolioStreams(
    Stream<DocumentSnapshot> walletStream,
    Stream<List<Map<String, dynamic>>> txStream,
  ) {
    late StreamController<PortfolioData> controller;
    DocumentSnapshot? lastWallet;
    List<Map<String, dynamic>>? lastTx;
    StreamSubscription? walletSub;
    StreamSubscription? txSub;

    void update() {
      if (lastWallet != null && lastTx != null && !controller.isClosed) {
        controller.add(PortfolioData(lastWallet!, lastTx!));
      }
    }

    controller = StreamController<PortfolioData>.broadcast(
      onListen: () {
        walletSub = walletStream.listen(
          (wallet) {
            lastWallet = wallet;
            update();
          },
          onError: controller.addError,
        );
        txSub = txStream.listen(
          (tx) {
            lastTx = tx;
            update();
          },
          onError: controller.addError,
        );
      },
      onCancel: () {
        walletSub?.cancel();
        txSub?.cancel();
        lastWallet = null;
        lastTx = null;
      },
    );

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> fetchUserTransactions(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) {
              return {
                'id': doc.id,
                ...doc.data(),
              };
            }).toList());
  }

  Stream<DocumentSnapshot> fetchWalletStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();
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
    if (isRefreshing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (coinMarket == null || coinMarket!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).extension<TradingColors>()!.warning,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _marketError?.message ?? 'Market data couldn\'t be loaded. Please try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => getCoinMarket(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
                child: StreamBuilder<PortfolioData>(
                  stream: _portfolioStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || !snapshot.data!.walletDoc.exists) {
                      return const Text('No wallet data found.');
                    }

                    final userData =
                        snapshot.data!.walletDoc.data() as Map<String, dynamic>;
                    final walletAmount = (userData['wallet'] ?? 0).toDouble();

                    double inPositions = 0.0;
                    double equityPositions = 0.0;
                    final transactions = snapshot.data!.transactions;
                    final hasMarketData = coinMarket != null && coinMarket!.isNotEmpty;

                    for (var tx in transactions) {
                      final type = tx['type'];
                      if (type != 'Buy' && type != 'Sell') continue;
                      final cost = (tx['cost'] as num?)?.toDouble();
                      if (cost != null) {
                        inPositions += cost;
                      }

                      if (hasMarketData) {
                        final matchingCoins = coinMarket!.where((coin) => coin.id == tx['coinId']);
                        if (matchingCoins.isNotEmpty) {
                          final coinData = matchingCoins.first;
                          final entryPrice = (tx['price'] as num?)?.toDouble() ?? 0.0;
                          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                          final currentPrice = (coinData.currentPrice as num?)?.toDouble() ?? 0.0;
                          final profit = computePnl(
                            type: type,
                            entryPrice: entryPrice,
                            currentPrice: currentPrice,
                            amount: amount,
                          );
                          final txCost = cost ?? 0.0;
                          equityPositions += max(0.0, txCost + profit);
                        }
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
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (hasMarketData) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Equity: \$${formatUsd(equity)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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
            if (isRefreshing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (coinMarket == null || coinMarket!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: Theme.of(context).extension<TradingColors>()!.warning,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _marketError?.message ?? 'Market data couldn\'t be loaded. Please try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => getCoinMarket(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _assetsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading transactions'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                            child: Text('No transactions found.')),
                      ),
                    );
                  }

                  userTransactions = List.of(snapshot.data!);
                  userTransactions!.sort((a, b) {
                    DateTime dateA = DateTime.parse(a['date']);
                    DateTime dateB = DateTime.parse(b['date']);
                    return dateB.compareTo(dateA);
                  });

                  return ListView.builder(
                    itemCount: userTransactions!.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final transaction = userTransactions![index];

                      final matchingCoins = coinMarket!.where((coin) => coin.id == transaction['coinId']);
                      if (matchingCoins.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final coinData = matchingCoins.first;

                      final type = transaction['type'];
                      if (type != 'Buy' && type != 'Sell') {
                        return const SizedBox.shrink();
                      }

                      final entryPrice = (transaction['price'] as num?)?.toDouble() ?? 0.0;
                      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                      final currentPrice = (coinData.currentPrice as num?)?.toDouble() ?? 0.0;

                      final profit = computePnl(
                        type: type as String,
                        entryPrice: entryPrice,
                        currentPrice: currentPrice,
                        amount: amount,
                      );

                      return InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Transaction Details'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Coin: ${coinData.id}'),
                                    Text('Amount: ${transaction['amount']}'),
                                    Text('Price: \$${transaction['price']}'),
                                    Text('Type: ${tradeLabel(type)}'),
                                    Text('Profit: ${formatSignedUsd(profit)}'),
                                    Text(
                                        'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(transaction['date']))}'),
                                    Text('Current Price: \$${coinData.currentPrice}'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Close'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final confirm =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Confirm Close Trade'),
                                            content: const Text(
                                                'Are you sure you want to close this trade?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context,
                                                        false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context,
                                                        true),
                                                child: const Text('Close Trade'),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirm == true) {
                                        try {
                                          final freshPrice = await MarketRepository.instance.getFreshPrice(coinData.id);
                                          await TradeService().closeTrade(
                                            userId: userId,
                                            transactionId: transaction['id'],
                                            currentPrice: freshPrice,
                                          );
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                                  context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Trade closed at \$${formatUsd(freshPrice)}')),
                                          );
                                        } catch (e) {
                                          final message = e.toString().replaceFirst(RegExp(r'^(Exception|Invalid argument\(s\)):\s*'), '');
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                                  context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Failed to close trade: $message')),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Close Trade'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Item(
                          item: coinData,
                          transaction: transaction,
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
            if (isRefreshing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (coinMarket == null || coinMarket!.isEmpty)
              const SizedBox.shrink()
            else
              SizedBox(
                height: 170,
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
    if (isRefreshing || coinMarket == null || coinMarket!.isEmpty) {
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
    if (isRefreshing || coinMarket == null || coinMarket!.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => _buildStateWidgetForTab(constraints),
      );
    }

    final sortedByChange = List<CoinModel>.from(coinMarket!)
      ..sort((a, b) => b.marketCapChangePercentage24H.compareTo(a.marketCapChangePercentage24H));

    final topGainers = sortedByChange.take(5).toList();
    final topLosers = sortedByChange.reversed.take(5).toList();

    return RefreshIndicator(
      onRefresh: () => getCoinMarket(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
      });
      if (mounted && userId.isNotEmpty && coinMarket != null && coinMarket!.isNotEmpty) {
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
    if (_liquidating || userId.isEmpty || coinMarket == null || coinMarket!.isEmpty) {
      return;
    }
    _liquidating = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .get();

      final List<String> liquidatedCoins = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'];
        final coinId = data['coinId'];
        final cost = (data['cost'] as num?)?.toDouble();

        if (type != 'Sell' || coinId == null || cost == null) continue;

        final matchingCoins = coinMarket!.where((c) => c.id == coinId);
        if (matchingCoins.isEmpty) continue;
        final coinData = matchingCoins.first;

        final entryPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final currentPrice = (coinData.currentPrice as num).toDouble();

        if (isLiquidated(
          type: 'Sell',
          entryPrice: entryPrice,
          currentPrice: currentPrice,
          amount: amount,
          cost: cost,
        )) {
          double freshPrice;
          try {
            freshPrice = await MarketRepository.instance.getFreshPrice(coinId.toString());
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
                transactionId: doc.id,
                currentPrice: freshPrice,
              );
              liquidatedCoins.add(coinId.toString());
            } catch (_) {}
          }
        }
      }

      if (liquidatedCoins.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Short on ${liquidatedCoins.join(', ')} was liquidated')),
        );
      }
    } catch (_) {
      // Ignore errors
    } finally {
      _liquidating = false;
    }
  }
}
