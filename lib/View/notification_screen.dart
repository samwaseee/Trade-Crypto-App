import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  Future<List<CoinModel>>? coinMarketFuture;

  @override
  void initState() {
    super.initState();
    coinMarketFuture = getCoinMarket(); // Initialize coinMarketFuture
  }

  Future<List<CoinModel>> getCoinMarket() async {
    const url =
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&sparkline=true';

    var response = await http.get(Uri.parse(url), headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return List<CoinModel>.from(data.map((item) => CoinModel.fromJson(item)));
    } else {
      throw Exception('Failed to load coin market data');
    }
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
          ...doc.data() as Map<String, dynamic>,
        };
        print('Fetched transaction: $transactionData');
        return transactionData;
      }).toList();

      print('Total transactions fetched: ${data.length}');
      return data;
    });
  }

  Future<List<String>> checkNotifications(
      List<Map<String, dynamic>> transactions, List<CoinModel> coinMarket) async {
    List<String> notifications = [];

    for (var transaction in transactions) {
      String coinId = transaction['coinId'];
      double amount = transaction['amount'];

      final coinData = coinMarket.firstWhere((coin) => coin.id == coinId,
          orElse: () => CoinModel(id: coinId, marketCapChangePercentage24H: 0));
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.yellow,
        title: Text('Recent Trade Changes'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fetchUserTransactions(userId),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (transactionSnapshot.hasError) {
            return Center(child: Text('Error: ${transactionSnapshot.error}'));
          }

          if (!transactionSnapshot.hasData || transactionSnapshot.data!.isEmpty) {
            return Center(child: Text('No transactions found.'));
          }

          return FutureBuilder<List<CoinModel>>(
            future: coinMarketFuture, // Use coinMarketFuture here
            builder: (context, coinMarketSnapshot) {
              if (coinMarketSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (coinMarketSnapshot.hasError) {
                return Center(child: Text('Error: ${coinMarketSnapshot.error}'));
              }

              if (!coinMarketSnapshot.hasData || coinMarketSnapshot.data!.isEmpty) {
                return Center(child: Text('No coin market data found.'));
              }

              final transactions = transactionSnapshot.data!;
              final coinMarket = coinMarketSnapshot.data!;

              return FutureBuilder<List<String>>(
                future: checkNotifications(transactions, coinMarket),
                builder: (context, notificationSnapshot) {
                  if (notificationSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (notificationSnapshot.hasError) {
                    return Center(
                        child: Text('Error: ${notificationSnapshot.error}'));
                  }

                  if (!notificationSnapshot.hasData ||
                      notificationSnapshot.data!.isEmpty) {
                    return Center(
                        child: Text('No significant market changes.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: notificationSnapshot.data!.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: Color(0xffFBC700),
                          size: 30.0,
                        ),
                        title: Text(
                          notificationSnapshot.data![index],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Notification received',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xffFBC700),
                          size: 20.0,
                        ),
                        tileColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          side: BorderSide(color: Color(0xffFBC700), width: 1),
                        ),
                      );
                    },
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

class CoinModel {
  final String id;
  final double marketCapChangePercentage24H;

  CoinModel({required this.id, required this.marketCapChangePercentage24H});

  factory CoinModel.fromJson(Map<String, dynamic> json) {
    return CoinModel(
      id: json['id'],
      marketCapChangePercentage24H: (json['market_cap_change_percentage_24h'] ??
          0)
          .toDouble(),
    );
  }
}
