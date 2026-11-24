import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Model/coinModel.dart';
import '../Services/market_repository.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  Future<List<CoinModel>>? coinMarketFuture;
  late final Stream<List<Map<String, dynamic>>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _transactionsStream = fetchUserTransactions(userId);
    coinMarketFuture = getCoinMarket();
  }

  Future<List<CoinModel>> getCoinMarket() async {
    return MarketRepository.instance.getMarkets();
  }

  Stream<List<Map<String, dynamic>>> fetchUserTransactions(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .snapshots()
        .map((querySnapshot) {
      final data = querySnapshot.docs.map((doc) {
        final transactionData = {
          'id': doc.id,
          ...doc.data(),
        };
        return transactionData;
      }).toList();

      return data;
    });
  }

  List<String> checkNotifications(
      List<Map<String, dynamic>> transactions, List<CoinModel> coinMarket) {
    List<String> notifications = [];

    for (var transaction in transactions) {
      String coinId = transaction['coinId'];

      final coinData = coinMarket.firstWhere((coin) => coin.id == coinId,
          orElse: () => CoinModel(
                id: coinId,
                symbol: coinId,
                name: coinId,
                image: '',
                currentPrice: 0,
                marketCapRank: 0,
                totalVolume: 0,
                high24H: 0,
                low24H: 0,
                priceChange24H: 0,
                marketCapChangePercentage24H: 0,
                sparklineIn7D: SparklineIn7D(price: []),
              ));
      double marketCapChange = coinData.marketCapChangePercentage24H;

      if (marketCapChange.abs() > 5) {
        notifications.add(
            '${coinId.toUpperCase()} market has changed by ${marketCapChange.toStringAsFixed(2)}% in the last 24 hours.');
      }
    }

    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Trade Changes'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _transactionsStream,
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (transactionSnapshot.hasError) {
            return Center(child: Text('Error: ${transactionSnapshot.error}'));
          }

          if (!transactionSnapshot.hasData || transactionSnapshot.data!.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          return FutureBuilder<List<CoinModel>>(
            future: coinMarketFuture,
            builder: (context, coinMarketSnapshot) {
              if (coinMarketSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (coinMarketSnapshot.hasError) {
                return Center(child: Text('Error: ${coinMarketSnapshot.error}'));
              }

              if (!coinMarketSnapshot.hasData || coinMarketSnapshot.data!.isEmpty) {
                return const Center(child: Text('No coin market data found.'));
              }

              final transactions = transactionSnapshot.data!;
              final coinMarket = coinMarketSnapshot.data!;
              final notifications = checkNotifications(transactions, coinMarket);

              if (notifications.isEmpty) {
                return const Center(
                    child: Text('No significant market changes.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              Icons.notifications_outlined,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notifications[index],
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Notification received',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
