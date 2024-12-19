import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/View/Components/item.dart';
import 'package:my_crypto/View/Components/item2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  int _selectedTabIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  Stream<List<Map<String, dynamic>>> fetchUserTransactions(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) {
              return {
                'id': doc.id, // Include the document ID
                ...doc.data()
                    as Map<String, dynamic>, // Include the document data
              };
            }).toList());
  }

  Stream<DocumentSnapshot> fetchWalletStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();
  }

  Future<void> closeTrade(
      String userId, String transactionId, double profit) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final transactionDoc =
        userDoc.collection('transactions').doc(transactionId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Fetch the user document
        DocumentSnapshot userSnapshot = await transaction.get(userDoc);

        // Check if the user document exists
        if (!userSnapshot.exists) {
          throw Exception('User document does not exist.');
        }

        // Safely get the current wallet balance
        Map<String, dynamic> userData =
            userSnapshot.data() as Map<String, dynamic>;
        double currentWallet = (userData['wallet'] ?? 0).toDouble();

        // Calculate the new wallet balance
        double newWallet = currentWallet + profit;

        // Update the wallet balance
        transaction.update(userDoc, {'wallet': newWallet});

        // Delete the transaction document
        transaction.delete(transactionDoc);

        print('Trade closed successfully. Wallet updated to $newWallet.');
      });
    } catch (e) {
      print('Error in closeTrade: $e');
      throw Exception('Failed to close trade: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    double myHeight = MediaQuery.of(context).size.height;
    double myWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xfffde164),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _onTabTapped(0),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: myWidth * 0.02, vertical: myHeight * 0.005),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? Colors.white.withOpacity(0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Main portfolio',
                  style: TextStyle(
                    fontSize: 18,
                    color: _selectedTabIndex == 0 ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _onTabTapped(1),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: myWidth * 0.02, vertical: myHeight * 0.005),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? Colors.white.withOpacity(0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Top 10 coins',
                  style: TextStyle(
                    fontSize: 18,
                    color: _selectedTabIndex == 1 ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _onTabTapped(2),
              child: Text(
                'Experimental',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedTabIndex == 2 ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: _getBodyContent(_selectedTabIndex, myHeight, myWidth),
      ),
    );
  }

  Widget _getBodyContent(int index, double myHeight, double myWidth) {
    switch (index) {
      case 0:
        return Container(
          width: myWidth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 253, 225, 112),
                  Color(0xffFBC700),
                ]),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: fetchWalletStream(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(child: Text('No wallet data found.'));
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final walletAmount = userData['wallet'];

                  return Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.07),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$ ${walletAmount.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 35),
                        ),
                        Container(
                          padding: EdgeInsets.all(
                              MediaQuery.of(context).size.width * 0.02),
                          height: MediaQuery.of(context).size.height * 0.05,
                          width: MediaQuery.of(context).size.width * 0.1,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.5)),
                          child: Image.asset(
                            'assets/icons/5.1.png',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(
                height: myHeight * 0.02,
              ),
              Container(
                height: myHeight * 0.745,
                width: myWidth,
                decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                          blurRadius: 5,
                          color: Colors.grey.shade300,
                          spreadRadius: 3,
                          offset: Offset(0, 3))
                    ],
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(50),
                      topRight: Radius.circular(50),
                    )),
                child: Column(
                  children: [
                    SizedBox(
                      height: myHeight * 0.03,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: myWidth * 0.08),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assets',
                            style: TextStyle(fontSize: 20),
                          ),
                          Icon(Icons.add)
                        ],
                      ),
                    ),
                    Container(
                      height: myHeight * 0.37,
                      child: isRefreshing == true
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xffFBC700),
                              ),
                            )
                          : coinMarket == null || coinMarket!.isEmpty
                              ? Padding(
                                  padding: EdgeInsets.all(myHeight * 0.06),
                                  child: const Center(
                                    child: Text(
                                      'Attention this Api is free, so you cannot send multiple requests per second, please wait and try again later.',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                )
                              : StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: fetchUserTransactions(userId),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return const Center(
                                          child: Text(
                                              'Error loading transactions'));
                                    }
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child:
                                              Text('No transactions found.'));
                                    }

                                    userTransactions = snapshot.data;

                                    return ListView.builder(
                                      itemCount: userTransactions!.length,
                                      shrinkWrap: true,
                                      physics: AlwaysScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        // Sort transactions
                                        userTransactions!.sort((a, b) {
                                          DateTime dateA =
                                              DateTime.parse(a['date']);
                                          DateTime dateB =
                                              DateTime.parse(b['date']);
                                          return dateB.compareTo(dateA);
                                        });

                                        final transaction =
                                            userTransactions![index];
                                        double buyprofit = double.parse(
                                            (coinMarket!
                                                        .firstWhere((coin) =>
                                                            coin.id ==
                                                            transaction[
                                                                'coinId'])
                                                        .currentPrice -
                                                    transaction['price'])
                                                .toStringAsFixed(2));
                                        double sellprofit = double.parse(
                                            (transaction['price'] -
                                                    coinMarket!
                                                        .firstWhere((coin) =>
                                                            coin.id ==
                                                            transaction[
                                                                'coinId'])
                                                        .currentPrice)
                                                .toStringAsFixed(2));
                                        final coinData = coinMarket!.firstWhere(
                                            (coin) =>
                                                coin.id ==
                                                transaction['coinId']);

                                        return InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Text(
                                                      'Transaction Details'),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                          'Coin: ${coinData.id}'),
                                                      Text(
                                                          'Amount: ${transaction['amount']}'),
                                                      Text(
                                                          'Price: \$${transaction['price']}'),
                                                      Text(
                                                          '${transaction['type']}'),
                                                      transaction['type'] ==
                                                              'Buy'
                                                          ? Text(
                                                              'Profit: \$${buyprofit}')
                                                          : Text(
                                                              'Profit: \$${sellprofit}'),
                                                      Text(
                                                          'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(transaction['date']))}'),
                                                      Text(
                                                          'Current Price: \$${coinData.currentPrice}'),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                      child: Text('Close'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        final confirm =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (BuildContext
                                                              context) {
                                                            return AlertDialog(
                                                              title: Text(
                                                                  'Confirm Close Trade'),
                                                              content: Text(
                                                                  'Are you sure you want to close this trade?'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context,
                                                                          false),
                                                                  child: Text(
                                                                      'Cancel'),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context,
                                                                          true),
                                                                  child: Text(
                                                                      'Close Trade'),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );

                                                        if (confirm == true) {
                                                          try {
                                                            await closeTrade(
                                                                userId,
                                                                transaction[
                                                                    'id'],
                                                                transaction['type'] ==
                                                                        'Buy'
                                                                    ? buyprofit
                                                                    : sellprofit);
                                                            Navigator.pop(
                                                                context); // Close the transaction dialog
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      'Trade closed successfully!')),
                                                            );
                                                          } catch (e) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      'Failed to close trade: $e')),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      child:
                                                          Text('Close Trade'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: Item(
                                            item: coinData, // Coin market data
                                            transaction:
                                                transaction, // User transaction data
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                    ),
                    SizedBox(
                      height: myHeight * 0.02,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: myWidth * 0.05),
                      child: Row(
                        children: [
                          Text(
                            'Recommend to Buy',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: myHeight * 0.01,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: myWidth * 0.03),
                        child: isRefreshing == true
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xffFBC700),
                                ),
                              )
                            : coinMarket == null || coinMarket!.length == 0
                                ? Padding(
                                    padding: EdgeInsets.all(myHeight * 0.06),
                                    child: Center(
                                      child: Text(
                                        'Attention this Api is free, so you cannot send multiple requests per second, please wait and try again later.',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: coinMarket!.length,
                                    itemBuilder: (context, index) {
                                      return Item2(
                                        item: coinMarket![index],
                                      );
                                    },
                                  ),
                      ),
                    ),
                    SizedBox(
                      height: myHeight * 0.01,
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      case 1:
        return Text('Top 10 coins content');
      case 2:
        return Text('Experimental content');
      default:
        return Text('Main portfolio content');
    }
  }

  List? coinMarket = [];
  var coinMarketList;

  Future<List<CoinModel>?> getCoinMarket() async {
    const url =
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&sparkline=true';

    setState(() {
      isRefreshing = true;
    });
    var response = await http.get(Uri.parse(url), headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    });
    setState(() {
      isRefreshing = false;
    });
    if (response.statusCode == 200) {
      var x = response.body;
      coinMarketList = coinModelFromJson(x);
      setState(() {
        coinMarket = coinMarketList;
      });
    } else {
      throw Exception(response.statusCode);
    }
  }
}
