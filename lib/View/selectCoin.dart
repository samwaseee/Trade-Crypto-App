import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Model/article.dart';
import '../Model/chartModel.dart';
import '../Services/news_service.dart';
import '../utils/format.dart';

class SelectCoin extends StatefulWidget {
  final dynamic selectItem;

  const SelectCoin({super.key, this.selectItem});

  @override
  State<SelectCoin> createState() => _SelectCoinState();
}

class _SelectCoinState extends State<SelectCoin> {
  late TrackballBehavior trackballBehavior;
  late Future<NewsResponse> futureNews;

  User? user;
  Map<String, dynamic>? userData;

  double _amount = 1.0;
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

    _amountController.text = _amount.toStringAsFixed(2);
  }

  Future<void> fetchUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (!doc.exists) {
        throw Exception('User data does not exist!');
      }
    } catch (e) {
      debugPrint('Error fetching user data');
    }
  }

  Future<void> buyCoin(String coinId, double amount, double price) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final transactionsSubcollection = userDoc.collection('transactions');

    try {
      await transactionsSubcollection.add({
        'type': 'Buy',
        'coinId': coinId,
        'amount': amount,
        'price': price,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to record buy transaction.');
    }
  }

  Future<void> sellCoin(String coinId, double amount, double price) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final transactionsSubcollection = userDoc.collection('transactions');

    try {
      await transactionsSubcollection.add({
        'type': 'Sell',
        'coinId': coinId,
        'amount': amount,
        'price': price,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to record sell transaction.');
    }
  }

  void _increaseAmount() {
    setState(() {
      if (_amount < 100.0) {
        _amount += 0.01;
        _amountController.text = _amount.toStringAsFixed(2);
      }
    });
  }

  void _decreaseAmount() {
    setState(() {
      if (_amount > 0.01) {
        _amount -= 0.01;
        _amountController.text = _amount.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isPositive = widget.selectItem.marketCapChangePercentage24H >= 0;
    final changeColor = isPositive ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectItem.name),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Image.network(
                                    widget.selectItem.image,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.currency_bitcoin, size: 36),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.selectItem.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      widget.selectItem.symbol.toUpperCase(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${formatUsd(widget.selectItem.currentPrice)}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: changeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${isPositive ? '+' : ''}${widget.selectItem.marketCapChangePercentage24H.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: changeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stats Card (Low / High / Vol)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Low (24h)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${formatUsd(widget.selectItem.low24H)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'High (24h)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${formatUsd(widget.selectItem.high24H)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Volume',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${formatUsd(widget.selectItem.totalVolume)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Chart Container
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: SizedBox(
                          height: 260,
                          child: isRefresh
                              ? const Center(child: CircularProgressIndicator())
                              : itemChart == null
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Free API rate limit reached. Please try again in a few seconds.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                  : SfCartesianChart(
                                      trackballBehavior: trackballBehavior,
                                      zoomPanBehavior: ZoomPanBehavior(
                                        enablePinching: true,
                                        zoomMode: ZoomMode.x,
                                      ),
                                      primaryXAxis: const DateTimeAxis(),
                                      series: <CandleSeries>[
                                        CandleSeries<ChartModel, DateTime>(
                                          enableSolidCandles: true,
                                          enableTooltip: true,
                                          bullColor: Colors.green,
                                          bearColor: Colors.red,
                                          dataSource: itemChart!,
                                          xValueMapper: (ChartModel sales, _) =>
                                              DateTime.fromMillisecondsSinceEpoch(sales.time),
                                          lowValueMapper: (ChartModel sales, _) => sales.low,
                                          highValueMapper: (ChartModel sales, _) => sales.high,
                                          openValueMapper: (ChartModel sales, _) => sales.open,
                                          closeValueMapper: (ChartModel sales, _) => sales.close,
                                          animationDuration: 550,
                                        )
                                      ],
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Days selector buttons
                    Center(
                      child: SizedBox(
                        height: 36,
                        child: ListView.builder(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemCount: text.length,
                          itemBuilder: (context, index) {
                            final isSelected = textBool[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(text[index]),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    textBool = [false, false, false, false, false, false];
                                    textBool[index] = true;
                                  });
                                  setDays(text[index]);
                                  getChart();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // News Header
                    Text(
                      'Related News',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // News List
                    FutureBuilder<NewsResponse>(
                      future: futureNews,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Text('Could not load news');
                        }
                        if (!snapshot.hasData || snapshot.data!.articles.isEmpty) {
                          return const Text('No related news.');
                        }

                        return Column(
                          children: snapshot.data!.articles.map((article) {
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: article.imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          article.imageUrl!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.newspaper),
                                        ),
                                      )
                                    : const Icon(Icons.newspaper),
                                title: Text(
                                  article.title ?? 'No Title',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                onTap: () => _launchURL(article.link ?? ''),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar (Buy / Sell / Amount)
            Card(
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User not authenticated')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await buyCoin(
                              widget.selectItem.id,
                              _amount,
                              widget.selectItem.currentPrice,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Successfully bought $_amount ${widget.selectItem.id}')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: const Text('Buy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _decreaseAmount,
                          tooltip: 'Decrease amount',
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            readOnly: true,
                            controller: _amountController,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _increaseAmount,
                          tooltip: 'Increase amount',
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User not authenticated')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await sellCoin(
                              widget.selectItem.id,
                              _amount,
                              widget.selectItem.currentPrice,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text('Successfully sold $_amount ${widget.selectItem.id}')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: const Text('Sell'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> text = ['D', 'W', 'M', '3M', '6M', 'Y'];
  List<bool> textBool = [false, false, true, false, false, false];

  int days = 30;

  void setDays(String txt) {
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
    String url = 'https://api.coingecko.com/api/v3/coins/${widget.selectItem.id}/ohlc?vs_currency=usd&days=$days';

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
      debugPrint('Error getting chart: ${response.statusCode}');
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
