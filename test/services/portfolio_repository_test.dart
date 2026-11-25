import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';

void main() {
  group('PortfolioRepository', () {
    late FakeFirebaseFirestore firestore;
    late PortfolioRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = PortfolioRepository(firestore: firestore);
    });

    test('walletStream emits typed wallet data', () async {
      await firestore.collection('users').doc('user-1').set({'wallet': 1250.5});

      final wallet = await repository.walletStream('user-1').first;

      expect(wallet.exists, isTrue);
      expect(wallet.walletUsd, 1250.5);
    });

    test('transactionsStream maps documents to typed transactions', () async {
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('transactions')
          .doc('trade-1')
          .set({
        'type': 'Buy',
        'coinId': 'bitcoin',
        'amount': 2,
        'price': 100,
        'cost': 200,
        'date': '2026-01-02T03:04:05.000Z',
      });

      final transactions = await repository.transactionsStream('user-1').first;

      expect(transactions, hasLength(1));
      expect(transactions.single.id, 'trade-1');
      expect(transactions.single.coinId, 'bitcoin');
      expect(transactions.single.type, 'Buy');
      expect(transactions.single.amount, 2);
      expect(transactions.single.entryPrice, 100);
      expect(transactions.single.cost, 200);
      expect(
          transactions.single.date, DateTime.parse('2026-01-02T03:04:05.000Z'));
    });

    test('portfolioStream combines wallet, transactions, and position P/L',
        () async {
      final user = firestore.collection('users').doc('user-1');
      await user.set({'wallet': 500});
      await user.collection('transactions').doc('buy').set({
        'type': 'Buy',
        'coinId': 'bitcoin',
        'amount': 2,
        'price': 100,
        'cost': 200,
        'date': '2026-01-02T03:04:05.000Z',
      });
      await user.collection('transactions').doc('short').set({
        'type': 'Sell',
        'coinId': 'ethereum',
        'amount': 1,
        'price': 200,
        'cost': 200,
        'date': '2026-01-03T03:04:05.000Z',
      });

      final portfolio = await repository.portfolioStream(
        'user-1',
        currentPrices: {'bitcoin': 120, 'ethereum': 100},
      ).first;

      expect(portfolio.wallet.walletUsd, 500);
      expect(portfolio.hasMarketData, isTrue);
      expect(portfolio.transactions, hasLength(2));
      final positions = {
        for (final transaction in portfolio.transactions)
          transaction.coinId: transaction,
      };
      expect(positions['bitcoin']!.currentPrice, 120);
      expect(positions['bitcoin']!.unrealizedPnl, 40);
      expect(positions['ethereum']!.unrealizedPnl, 100);
    });

    test('portfolioStream sends the snapshot to both listeners', () async {
      await firestore.collection('users').doc('user-1').set({'wallet': 500});
      final portfolioStream = repository.portfolioStream('user-1');

      final snapshots = await Future.wait([
        portfolioStream.first,
        portfolioStream.first,
      ]);

      expect(snapshots, hasLength(2));
      expect(snapshots[0].wallet.walletUsd, 500);
      expect(snapshots[1].wallet.walletUsd, 500);
    });
  });
}
