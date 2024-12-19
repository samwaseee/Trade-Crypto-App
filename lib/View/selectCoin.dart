import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Model/article.dart';
import '../Model/chartModel.dart';
import '../Services/news_service.dart';

class SelectCoin extends StatefulWidget {
  var selectItem;

  SelectCoin({this.selectItem});

  @override
  State<SelectCoin> createState() => _SelectCoinState();
}

class _SelectCoinState extends State<SelectCoin> {
  late TrackballBehavior trackballBehavior;
  late Future<NewsResponse> futureNews;

  User? user;
  Map<String, dynamic>? userData;

  double _amount = 1.0; // Default amount
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    getChart();

    trackballBehavior = TrackballBehavior(
        enable: true, activationMode: ActivationMode.singleTap);
    super.initState();
    futureNews = NewsService().fetchNews(widget.selectItem.id);

    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      fetchUserData();
    }

    _amountController.text = _amount.toStringAsFixed(2); // Set default value in controller
  }

  Future<void> fetchUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (!doc.exists) {
        throw Exception('User data does not exist!');
      }
      // Handle user data here
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> buyCoin(String coinId, double amount, double price) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final transactionsSubcollection = userDoc.collection('transactions'); // Subcollection for transactions

    try {
      // Add a new transaction under the transactions subcollection
      await transactionsSubcollection.add({
        'type': 'Buy',               // Transaction type
        'coinId': coinId,            // Coin being bought
        'amount': amount,            // Amount of the coin bought
        'price': price,              // Price at which the coin was bought
        'date': DateTime.now().toIso8601String(), // Transaction date
      });

      print('Buy transaction recorded successfully.');
    } catch (e) {
      print('Error in buyCoin: $e');
      throw Exception('Failed to record buy transaction.');
    }
  }

  Future<void> sellCoin(String coinId, double amount, double price) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final transactionsSubcollection = userDoc.collection('transactions'); // Subcollection for transactions

    try {
      // Add a new transaction under the transactions subcollection
      await transactionsSubcollection.add({
        'type': 'Sell',              // Transaction type
        'coinId': coinId,            // Coin being sold
        'amount': amount,            // Amount of the coin sold
        'price': price,              // Price at which the coin was sold
        'date': DateTime.now().toIso8601String(), // Transaction date
      });

      print('Sell transaction recorded successfully.');
    } catch (e) {
      print('Error in sellCoin: $e');
      throw Exception('Failed to record sell transaction.');
    }
  }

  void _increaseAmount() {
    setState(() {
      if (_amount < 100.0) {
        _amount += 0.01; // Increase by 0.01, adjust for your preferred step
        _amountController.text = _amount.toStringAsFixed(2);
      }
    });
  }

  void _decreaseAmount() {
    setState(() {
      if (_amount > 0.01) {
        _amount -= 0.01; // Decrease by 0.01, adjust for your preferred step
        _amountController.text = _amount.toStringAsFixed(2);
      }
    });
  }




  @override
  Widget build(BuildContext context) {
    double myHeight = MediaQuery.of(context).size.height;
    double myWidth = MediaQuery.of(context).size.width;
    return SafeArea(
        child: Scaffold(
      body: Container(
        height: myHeight,
        width: myWidth,
        child: Column(
          children: [
            //Heading
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: myWidth * 0.05, vertical: myHeight * 0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                          height: myHeight * 0.08,
                          child: Image.network(widget.selectItem.image)),
                      SizedBox(
                        width: myWidth * 0.03,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.selectItem.id,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(
                            height: myHeight * 0.01,
                          ),
                          Text(
                            widget.selectItem.symbol,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$' + widget.selectItem.currentPrice.toString(),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.normal,
                            color: Colors.black),
                      ),
                      SizedBox(
                        height: myHeight * 0.01,
                      ),
                      Text(
                        widget.selectItem.marketCapChangePercentage24H
                                .toString() +
                            '%',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: widget.selectItem
                                        .marketCapChangePercentage24H >=
                                    0
                                ? Colors.green
                                : Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),


            Expanded(
                child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: myWidth * 0.05, vertical: myHeight * 0.02),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Low',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey),
                          ),
                          SizedBox(
                            height: myHeight * 0.01,
                          ),
                          Text(
                            '\$' + widget.selectItem.low24H.toString(),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.black),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'High',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey),
                          ),
                          SizedBox(
                            height: myHeight * 0.01,
                          ),
                          Text(
                            '\$' + widget.selectItem.high24H.toString(),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.black),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Vol',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey),
                          ),
                          SizedBox(
                            height: myHeight * 0.01,
                          ),
                          Text(
                            '\$' +
                                (widget.selectItem.totalVolume/1000).toString() +
                                'B',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: myHeight * 0.015,
                ),
                Container(
                  height: myHeight * 0.4,
                  width: myWidth,
                  // color: Colors.amber,
                  child: isRefresh == true
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xffFBC700),
                          ),
                        )
                      : itemChart == null
                          ? Padding(
                              padding: EdgeInsets.all(myHeight * 0.06),
                              child: Center(
                                child: Text(
                                  'Attention this Api is free, so you cannot send multiple requests per second, please wait and try again later.',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            )
                          : SfCartesianChart(
                              trackballBehavior: trackballBehavior,
                              zoomPanBehavior: ZoomPanBehavior(
                                  enablePinching: true, zoomMode: ZoomMode.x),
                              primaryXAxis: DateTimeAxis(),
                              series: <CandleSeries>[
                                CandleSeries<ChartModel, DateTime>(
                                    enableSolidCandles: true,
                                    enableTooltip: true,
                                    bullColor: Colors.green,
                                    bearColor: Colors.red,
                                    dataSource: itemChart!,
                                    xValueMapper: (ChartModel sales, _) =>
                                        DateTime.fromMillisecondsSinceEpoch(sales.time),
                                    lowValueMapper: (ChartModel sales, _) =>
                                        sales.low,
                                    highValueMapper: (ChartModel sales, _) =>
                                        sales.high,
                                    openValueMapper: (ChartModel sales, _) =>
                                        sales.open,
                                    closeValueMapper: (ChartModel sales, _) =>
                                        sales.close,
                                    animationDuration: 550)
                              ],
                            ),
                ),
                SizedBox(
                  height: myHeight * 0.01,
                ),
                Center(
                  child: Container(
                    height: myHeight * 0.04,
                    child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: text.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: myWidth * 0.02),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                textBool = [
                                  false,
                                  false,
                                  false,
                                  false,
                                  false,
                                  false
                                ];
                                textBool[index] = true;
                              });
                              setDays(text[index]);
                              getChart();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: myWidth * 0.03,
                                  vertical: myHeight * 0.005),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: textBool[index] == true
                                    ? Color(0xffFBC700).withOpacity(0.3)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                text[index],
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: myHeight * 0.01,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: myWidth * 0.06),
                  child: Text(
                    'News',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        FutureBuilder<NewsResponse>(
                          future: futureNews,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Column(
                                children: snapshot.data!.articles.map((article) {
                                  return ListTile(
                                    trailing: article.imageUrl != null
                                        ? SizedBox(
                                      width: 100, // Set the width
                                      height: 80, // Set the height
                                      child: Image.network(
                                        article.imageUrl!,
                                        errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                        : const Icon(Icons.image, size: 100),
                                    title: Text(article.title ?? 'No Title'),
                                    onTap: () => _launchURL(article.link ?? ''),
                                  );
                                }).toList(),
                              );
                            } else if (snapshot.hasError) {
                              return Text("${snapshot.error}");
                            }
                            return CircularProgressIndicator();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )),
            Container(
              height: myHeight * 0.09,
              width: myWidth,
              // color: Colors.amber,
              child: Column(
                children: [
                  Divider(),
                  SizedBox(
                    height: myHeight * 0.0,
                  ),
                  Row(
                    children: [
                      SizedBox(width: myWidth * 0.02),
                      Expanded(
                        flex: 5,
                        child: GestureDetector(
                          onTap: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('User not authenticated')),
                              );
                              return;
                            }

                            try {
                              // Call buy function
                              await buyCoin(
                                widget.selectItem.id,
                                _amount, // Use the amount selected
                                widget.selectItem.currentPrice,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Successfully bought $_amount ${widget.selectItem.id}')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: myHeight * 0.015),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                color: Color(0xff1cad1f)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Buy',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: _decreaseAmount,
                            tooltip: 'Decrease amount',
                          ),
                          Container(
                            width: myWidth * 0.2,
                            child: TextField(
                              readOnly: true,
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                hintText: 'Enter amount',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                final parsedAmount = double.tryParse(value) ?? 0.01;
                                if (_amount != parsedAmount) {
                                  setState(() {
                                    _amount = parsedAmount.clamp(0.01, 100.0); // Ensure range
                                    _amountController.text = _amount.toStringAsFixed(2);
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: _increaseAmount,
                            tooltip: 'Increase amount',
                          ),
                        ],
                      ),
                      Expanded(
                        flex: 5,
                        child: GestureDetector(
                          onTap: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('User not authenticated')),
                              );
                              return;
                            }

                            try {
                              // Call sell function
                              await sellCoin(
                                widget.selectItem.id,
                                _amount, // Use the amount selected
                                widget.selectItem.currentPrice,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Successfully sold $_amount ${widget.selectItem.id}')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: myHeight * 0.015),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                color: Color(0xd5ff1200)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sell',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: myWidth * 0.02),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    ));
  }

  List<String> text = ['D', 'W', 'M', '3M', '6M', 'Y'];
  List<bool> textBool = [false, false, true, false, false, false];

  int days = 30;

  setDays(String txt) {
    if (txt == 'D') {
      setState(() {
        days = 1;
      });
    } else if (txt == 'W') {
      setState(() {
        days = 7;
      });
    } else if (txt == 'M') {
      setState(() {
        days = 30;
      });
    } else if (txt == '3M') {
      setState(() {
        days = 90;
      });
    } else if (txt == '6M') {
      setState(() {
        days = 180;
      });
    } else if (txt == 'Y') {
      setState(() {
        days = 365;
      });
    }
  }

  List<ChartModel>? itemChart;

  bool isRefresh = true;

  Future<void> getChart() async {
    String url = 'https://api.coingecko.com/api/v3/coins/' +
        widget.selectItem.id +
        '/ohlc?vs_currency=usd&days=' +
        days.toString();

    setState(() {
      isRefresh = true;
    });

    var response = await http.get(Uri.parse(url), headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    });

    setState(() {
      isRefresh = false;
    });
    if (response.statusCode == 200) {
      Iterable x = json.decode(response.body);
      List<ChartModel> modelList =
          x.map((e) => ChartModel.fromJson(e)).toList();
      setState(() {
        itemChart = modelList;
      });
    } else {
      print(response.statusCode);
    }
  }

  Future<void> _launchURL(String url) async {
    if (url.isNotEmpty) {
      if (!await launchUrl(Uri.parse(url))) {
        throw 'Could not launch $url';
      }
    }
  }
}
