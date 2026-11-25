import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/Services/market_repository.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';
import 'package:my_crypto/theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final String userId;
  Future<List<CoinModel>>? coinMarketFuture;
  late final Stream<List<PortfolioTransaction>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('NotificationScreen requires an authenticated user.');
    }
    userId = uid;
    _transactionsStream =
        PortfolioRepository.instance.transactionsStream(userId);
    coinMarketFuture = getCoinMarket();
  }

  Future<List<CoinModel>> getCoinMarket() async {
    return MarketRepository.instance.getMarkets();
  }

  List<String> checkNotifications(
    List<PortfolioTransaction> transactions,
    List<CoinModel> coinMarket,
  ) {
    final notifications = <String>[];
    final seenCoinIds = <String>{};
    final coinsById = {for (final coin in coinMarket) coin.id: coin};

    for (final transaction in transactions) {
      final coinId = transaction.coinId;
      if (!seenCoinIds.add(coinId)) continue;

      final coin = coinsById[coinId];
      if (coin == null) continue;
      final priceChange = coin.priceChangePercentage24h;

      if (priceChange.abs() > 5) {
        notifications.add(
          '${coinId.toUpperCase()} market has changed by ${priceChange.toStringAsFixed(2)}% in the last 24 hours.',
        );
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
      body: StreamBuilder<List<PortfolioTransaction>>(
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
                              color: theme.colorScheme.accent,
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
