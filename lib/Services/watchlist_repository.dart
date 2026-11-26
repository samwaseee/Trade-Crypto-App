import 'package:cloud_firestore/cloud_firestore.dart';

import '../Model/watchlist_coin.dart';

class WatchlistRepository {
  WatchlistRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final WatchlistRepository instance = WatchlistRepository();

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _watchlist(String uid) =>
      _firestore.collection('users').doc(uid).collection('watchlist');

  Stream<List<WatchlistCoin>> watchlistStream(String uid) {
    return _watchlist(uid).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => WatchlistCoin.fromFirestore(doc.id, doc.data()))
              .whereType<WatchlistCoin>()
              .toList(growable: false),
        );
  }

  Future<void> addCoin(String uid, WatchlistCoin coin) {
    return _watchlist(uid).doc(coin.id).set(coin.toFirestore());
  }

  Future<void> removeCoin(String uid, String coinId) {
    return _watchlist(uid).doc(coinId).delete();
  }
}
