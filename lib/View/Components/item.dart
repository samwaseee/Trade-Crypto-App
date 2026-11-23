import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:material_ui/material_ui.dart';

class Item extends StatelessWidget {
  final dynamic item;
  final dynamic transaction;

  const Item({super.key, this.item, this.transaction});


  @override
  Widget build(BuildContext context) {
    double myHeight = MediaQuery.of(context).size.height;
    double myWidth = MediaQuery.of(context).size.width;
    final buyprofit = double.parse((item.currentPrice - transaction['price']).toStringAsFixed(2));
    final sellprofit = double.parse((transaction['price'] - item.currentPrice).toStringAsFixed(2));

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: myWidth * 0.03, vertical: myHeight * 0.02),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
                height: myHeight * 0.05, child: Image.network(item.image)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.id,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: myWidth * 0.02,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          transaction['amount'].toStringAsFixed(2),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey),
                        ),
                        SizedBox(
                          width: myWidth * 0.03,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: myWidth * 0.009),
                          decoration: BoxDecoration(
                            color: transaction['type'] == 'Buy'
                                ? buyprofit >= 0
                                ? Colors.green
                                : Colors.red
                                : sellprofit >= 0
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                          child: Text(
                            transaction['type'],
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: Colors.white
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: myWidth * 0.01,
                    ),
                    Text(
                      'at  \$${transaction['price']}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.blueGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: myWidth * 0.01,
          ),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: myHeight * 0.05,
              child: Sparkline(
                data: item.sparklineIn7D.price,
                lineWidth: 2.0,
                lineColor: transaction['type'] == 'Buy' ? buyprofit >= 0
                    ? Colors.green
                    : Colors.red : sellprofit >= 0
                    ? Colors.green
                    : Colors.red,
                fillMode: FillMode.below,
                fillGradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.7],
                    colors: transaction['type'] == 'Buy' ? buyprofit >= 0
                        ? [Colors.green, Colors.green.withValues(alpha: 0.1)]
                        : [Colors.red, Colors.red.withValues(alpha: 0.1)] : sellprofit >= 0
                        ? [Colors.green, Colors.green.withValues(alpha: 0.1)]
                        : [Colors.red, Colors.red.withValues(alpha: 0.1)])
              ),
            ),
          ),
          SizedBox(
            width: myWidth * 0.04,
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                transaction['type'] == 'Buy' ? Text(
                  '\$ $buyprofit',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: buyprofit >= 0
                          ? Colors.green
                          : Colors.red),
                ) : Text(
                  '\$ $sellprofit',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: sellprofit >= 0
                          ? Colors.green
                          : Colors.red),
                ),
                Row(
                  children: [
                    Text(
                      item.currentPrice.toString(),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey),
                    ),
                    SizedBox(
                      width: myWidth * 0.03,
                    ),
                    Text(
                      item.marketCapChangePercentage24H.toStringAsFixed(2) +
                          '%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: item.marketCapChangePercentage24H >= 0
                              ? Colors.green
                              : Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
