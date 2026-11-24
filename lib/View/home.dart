import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/View/Components/coin_tile.dart';
import 'package:my_crypto/View/Components/item.dart';
import 'package:my_crypto/View/Components/item2.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:my_crypto/Services/trade_service.dart';
import 'package:my_crypto/utils/format.dart';
import 'package:my_crypto/utils/pnl.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isRefreshing = true;
  List? userTransactions = [];

  @override
  void initState() {
    getCoinMarket();
    super.initState();
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
                  const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  const Text(
                    'Market data couldn\'t be loaded (Free API rate limited). Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
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
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStateWidgetForTab(BoxConstraints constraints) {
    final stateWidget = _buildMarketStateWidget();
    return RefreshIndicator(
      onRefresh: getCoinMarket,
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
      onRefresh: getCoinMarket,
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
                child: StreamBuilder<DocumentSnapshot>(
                  stream: fetchWalletStream(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Text('No wallet data found.');
                    }

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final walletAmount = (userData['wallet'] ?? 0).toDouble();

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet balance',
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
                      const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text(
                        'Market data couldn\'t be loaded (Free API rate limited). Please try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
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
                stream: fetchUserTransactions(userId),
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

                  userTransactions = snapshot.data;
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
                                    Text('Type: $type'),
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
                                          await TradeService().closeTrade(
                                            userId: userId,
                                            transactionId: transaction['id'],
                                            currentPrice: (coinData.currentPrice as num).toDouble(),
                                          );
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                                  context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Trade closed successfully!')),
                                          );
                                        } catch (e) {
                                          final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
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
                height: 160,
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
      onRefresh: getCoinMarket,
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
      onRefresh: getCoinMarket,
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

  Future<void> getCoinMarket() async {
    const url =
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&sparkline=true';

    setState(() {
      isRefreshing = true;
    });
    try {
      var response = await http.get(Uri.parse(url), headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      });
      if (!mounted) return;
      setState(() {
        isRefreshing = false;
      });
      if (response.statusCode == 200) {
        var x = response.body;
        coinMarketList = coinModelFromJson(x);
        if (!mounted) return;
        setState(() {
          coinMarket = coinMarketList;
        });
      } else {
        if (!mounted) return;
        setState(() {
          coinMarket = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isRefreshing = false;
        coinMarket = [];
      });
    }
  }
}
