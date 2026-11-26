import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Model/watchlist_coin.dart';
import 'package:my_crypto/Services/watchlist_repository.dart';

void main() {
  group('WatchlistRepository', () {
    late FakeFirebaseFirestore firestore;
    late WatchlistRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = WatchlistRepository(firestore: firestore);
    });

    test('adds and removes a coin from the signed-in user watchlist', () async {
      const coin = WatchlistCoin(
        id: 'bitcoin',
        name: 'Bitcoin',
        symbol: 'btc',
        image: 'https://example.com/bitcoin.png',
      );

      await repository.addCoin('user-1', coin);
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('watchlist')
          .doc('invalid-type')
          .set({'name': 123, 'symbol': 'bad', 'image': ''});
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('watchlist')
          .doc('missing-field')
          .set({'name': 'Missing image', 'symbol': 'miss'});
      final savedCoins = await repository.watchlistStream('user-1').first;

      expect(savedCoins, hasLength(1));
      expect(savedCoins.single.id, 'bitcoin');
      expect(savedCoins.single.name, 'Bitcoin');
      expect(savedCoins.single.symbol, 'btc');
      expect(savedCoins.single.image, 'https://example.com/bitcoin.png');
      expect(
        (await firestore
                .collection('users')
                .doc('user-1')
                .collection('watchlist')
                .doc('bitcoin')
                .get())
            .data(),
        {
          'name': 'Bitcoin',
          'symbol': 'btc',
          'image': 'https://example.com/bitcoin.png',
        },
      );

      await repository.removeCoin('user-1', 'bitcoin');
      expect(await repository.watchlistStream('user-1').first, isEmpty);
    });
  });
}
