import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/pnl.dart';

class PortfolioWallet {
  const PortfolioWallet({
    required this.exists,
    required this.walletUsd,
  });

  final bool exists;
  final double walletUsd;
}

class PortfolioTransaction {
  const PortfolioTransaction({
    required this.id,
    required this.type,
    required this.coinId,
    required this.amount,
    required this.entryPrice,
    required this.cost,
    required this.date,
    this.currentPrice,
    this.unrealizedPnl,
  });

  final String id;
  final String type;
  final String coinId;
  final double amount;
  final double entryPrice;
  final double cost;
  final DateTime date;
  final double? currentPrice;
  final double? unrealizedPnl;

  factory PortfolioTransaction.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDate = data['date'];
    final date = switch (rawDate) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      String value =>
        DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0),
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

    double readNumber(String key) => (data[key] as num?)?.toDouble() ?? 0.0;

    return PortfolioTransaction(
      id: id,
      type: data['type'] as String? ?? '',
      coinId: data['coinId'] as String? ?? '',
      amount: readNumber('amount'),
      entryPrice: readNumber('price'),
      cost: readNumber('cost'),
      date: date,
    );
  }

  PortfolioTransaction withMarketPrice(double? price) {
    if (price == null || !price.isFinite || price < 0) {
      return this;
    }

    final pnl = switch (type) {
      'Buy' || 'Sell' => computePnl(
          type: type,
          entryPrice: entryPrice,
          currentPrice: price,
          amount: amount,
        ),
      _ => null,
    };

    return PortfolioTransaction(
      id: id,
      type: type,
      coinId: coinId,
      amount: amount,
      entryPrice: entryPrice,
      cost: cost,
      date: date,
      currentPrice: price,
      unrealizedPnl: pnl,
    );
  }

  /// Converts to the legacy map shape required by existing trade detail widgets.
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'coinId': coinId,
        'amount': amount,
        'price': entryPrice,
        'cost': cost,
        'date': date.toIso8601String(),
      };
}

class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.wallet,
    required this.transactions,
    required this.hasMarketData,
  });

  final PortfolioWallet wallet;
  final List<PortfolioTransaction> transactions;
  final bool hasMarketData;
}

class PortfolioRepository {
  PortfolioRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final PortfolioRepository instance = PortfolioRepository();

  final FirebaseFirestore _firestore;

  Stream<PortfolioWallet> walletStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final wallet = snapshot.data()?['wallet'];
      return PortfolioWallet(
        exists: snapshot.exists,
        walletUsd: (wallet as num?)?.toDouble() ?? 0.0,
      );
    });
  }

  Stream<List<PortfolioTransaction>> transactionsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(
                (doc) => PortfolioTransaction.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Stream<PortfolioSnapshot> portfolioStream(
    String uid, {
    Map<String, double> currentPrices = const {},
  }) {
    return Stream<PortfolioSnapshot>.multi((controller) {
      PortfolioWallet? wallet;
      List<PortfolioTransaction>? transactions;

      void emitIfReady() {
        if (wallet == null || transactions == null) return;
        controller.add(
          PortfolioSnapshot(
            wallet: wallet!,
            transactions: transactions!
                .map((transaction) => transaction.withMarketPrice(
                      currentPrices[transaction.coinId],
                    ))
                .toList(growable: false),
            hasMarketData: currentPrices.isNotEmpty,
          ),
        );
      }

      final walletSubscription = walletStream(uid).listen(
        (value) {
          wallet = value;
          emitIfReady();
        },
        onError: controller.addError,
      );
      final transactionsSubscription = transactionsStream(uid).listen(
        (value) {
          transactions = value;
          emitIfReady();
        },
        onError: controller.addError,
      );

      controller.onCancel = () async {
        await walletSubscription.cancel();
        await transactionsSubscription.cancel();
      };
    });
  }
}
