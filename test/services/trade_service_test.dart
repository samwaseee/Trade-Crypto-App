import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Services/trade_service.dart';

void main() {
  group('TradeService.closeTrade', () {
    test('records a closed long and returns its realized P&L', () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-long');
      await user.set({'wallet': 1000.0});
      final service = TradeService(firestore: firestore);

      await service.openTrade(
        userId: 'user-long',
        coinId: 'bitcoin',
        type: 'Buy',
        amount: 2,
        price: 100,
      );
      final openTrades = await user.collection('transactions').get();
      final openTradeRef = openTrades.docs.single.reference;

      final realizedPnl = await service.closeTrade(
        userId: 'user-long',
        transactionId: openTradeRef.id,
        currentPrice: 150,
        coinName: 'Bitcoin',
        coinSymbol: 'btc',
        coinImage: 'https://example.com/bitcoin.png',
      );

      expect(realizedPnl, 100);
      expect((await user.get()).data()!['wallet'], 1100);
      expect((await openTradeRef.get()).exists, isFalse);

      final closed = await user.collection('closedTrades').get();
      expect(closed.docs, hasLength(1));
      final data = closed.docs.single.data();
      expect(data['type'], 'Buy');
      expect(data['coinId'], 'bitcoin');
      expect(data['coinName'], 'Bitcoin');
      expect(data['coinSymbol'], 'btc');
      expect(data['coinImage'], 'https://example.com/bitcoin.png');
      expect(data['entryPrice'], 100);
      expect(data['exitPrice'], 150);
      expect(data['cost'], 200);
      expect(data['realizedPnl'], 100);
      expect(data['closeReason'], 'manual');
      expect(data['openedAt'], isA<Timestamp>());
      expect(data['closedAt'], isA<Timestamp>());
    });

    test('records a manually closed short with its realized loss', () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-short');
      await user.set({'wallet': 1000.0});
      final service = TradeService(firestore: firestore);

      await service.openTrade(
        userId: 'user-short',
        coinId: 'ethereum',
        type: 'Sell',
        amount: 1,
        price: 100,
      );
      final openTrades = await user.collection('transactions').get();
      final openTradeRef = openTrades.docs.single.reference;

      final realizedPnl = await service.closeTrade(
        userId: 'user-short',
        transactionId: openTradeRef.id,
        currentPrice: 150,
        coinName: 'Ethereum',
        coinSymbol: 'eth',
        coinImage: '',
      );

      expect(realizedPnl, -50);
      expect((await user.get()).data()!['wallet'], 950);
      expect((await openTradeRef.get()).exists, isFalse);
      final closed = await user.collection('closedTrades').get();
      expect(closed.docs.single.data()['realizedPnl'], -50);
      expect(closed.docs.single.data()['closeReason'], 'manual');
    });

    test('caps a liquidated short loss at its collateral', () async {
      final firestore = FakeFirebaseFirestore();
      final user = firestore.collection('users').doc('user-liquidated');
      await user.set({'wallet': 1000.0});
      final service = TradeService(firestore: firestore);

      await service.openTrade(
        userId: 'user-liquidated',
        coinId: 'ethereum',
        type: 'Sell',
        amount: 1,
        price: 100,
      );
      final openTrades = await user.collection('transactions').get();
      final openTradeRef = openTrades.docs.single.reference;

      final realizedPnl = await service.closeTrade(
        userId: 'user-liquidated',
        transactionId: openTradeRef.id,
        currentPrice: 250,
        coinName: 'Ethereum',
        coinSymbol: 'eth',
        coinImage: '',
        closeReason: 'liquidated',
      );

      expect(realizedPnl, -100);
      expect((await user.get()).data()!['wallet'], 900);
      expect((await openTradeRef.get()).exists, isFalse);
      final closed = await user.collection('closedTrades').get();
      expect(closed.docs.single.data()['cost'], 100);
      expect(closed.docs.single.data()['realizedPnl'], -100);
      expect(closed.docs.single.data()['closeReason'], 'liquidated');
    });
  });
}
