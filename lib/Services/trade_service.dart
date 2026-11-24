import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_crypto/utils/format.dart';
import 'package:my_crypto/utils/pnl.dart';

class TradeService {
  final FirebaseFirestore _firestore;

  TradeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> openTrade({
    required String userId,
    required String coinId,
    required String type,
    required double amount,
    required double price,
  }) async {
    if (type != 'Buy' && type != 'Sell') {
      throw Exception("Invalid trade type: '$type'. Expected 'Buy' or 'Sell'.");
    }
    if (amount <= 0 || price <= 0) {
      throw Exception('Amount and price must be greater than zero.');
    }

    final cost = roundTo(amount * price, 8);
    final userDocRef = _firestore.collection('users').doc(userId);
    final newTransactionRef = userDocRef.collection('transactions').doc();

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocRef);
      if (!userSnapshot.exists) {
        throw Exception('User profile not found.');
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final currentWallet = (userData['wallet'] ?? 0.0) as num;

      if (currentWallet.toDouble() < cost) {
        if (type == 'Sell') {
          throw Exception(
              'Not enough collateral to open this short: need \$${formatUsd(cost)}, available \$${formatUsd(currentWallet.toDouble())}.');
        } else {
          throw Exception(
              'Not enough balance: need \$${formatUsd(cost)}, available \$${formatUsd(currentWallet.toDouble())}.');
        }
      }

      final newWallet = roundTo(currentWallet.toDouble() - cost, 8);

      transaction.update(userDocRef, {'wallet': newWallet});
      transaction.set(newTransactionRef, {
        'type': type,
        'coinId': coinId,
        'amount': amount,
        'price': price,
        'cost': cost,
        'date': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> closeTrade({
    required String userId,
    required String transactionId,
    required double currentPrice,
  }) async {
    final userDocRef = _firestore.collection('users').doc(userId);
    final transactionDocRef = userDocRef.collection('transactions').doc(transactionId);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocRef);
      final transactionSnapshot = await transaction.get(transactionDocRef);

      if (!userSnapshot.exists) {
        throw Exception('User profile not found.');
      }
      if (!transactionSnapshot.exists) {
        throw Exception('Transaction record not found.');
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final transactionData = transactionSnapshot.data() as Map<String, dynamic>;

      final currentWallet = (userData['wallet'] ?? 0.0) as num;
      final type = transactionData['type'];
      if (type != 'Buy' && type != 'Sell') {
        throw Exception("Invalid trade type in record: '$type'. Expected 'Buy' or 'Sell'.");
      }

      final entryPrice = (transactionData['price'] as num?)?.toDouble() ?? 0.0;
      final amount = (transactionData['amount'] as num?)?.toDouble() ?? 0.0;
      final storedCost = (transactionData['cost'] as num?)?.toDouble() ?? 0.0;

      final pnl = computePnl(
        type: type as String,
        entryPrice: entryPrice,
        currentPrice: currentPrice,
        amount: amount,
      );

      final rawReturnToWallet = storedCost + pnl;
      final returnToWallet = roundTo(rawReturnToWallet < 0 ? 0.0 : rawReturnToWallet, 8);
      final newWallet = roundTo(currentWallet.toDouble() + returnToWallet, 8);

      transaction.update(userDocRef, {'wallet': newWallet});
      transaction.delete(transactionDocRef);
    });
  }
}
