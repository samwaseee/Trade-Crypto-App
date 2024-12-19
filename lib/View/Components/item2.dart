import 'package:my_crypto/View/selectCoin.dart';
import 'package:flutter/material.dart';

class Item2 extends StatelessWidget {
  var item;
  Item2({this.item});

  @override
  Widget build(BuildContext context) {
    double myHeight = MediaQuery.of(context).size.height;
    double myWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: myWidth * 0.03, vertical: myHeight * 0.02),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (contest) => SelectCoin(selectItem: item,)));
        },
        child: Container(
          constraints: BoxConstraints(
            minWidth: myWidth * 0.42,
          ),
          padding: EdgeInsets.only(
            left: myWidth * 0.03,
            right: myWidth * 0.03,
            top: myHeight * 0.02,
            bottom: myHeight * 0.02,
          ),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xffFBC700)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0xffFBC700).withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 7,
              offset: Offset(4, 6), // changes position of shadow
            ),
          ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: myHeight * 0.04, child: Image.network(item.image)),
              SizedBox(
                height: myHeight * 0.02,
              ),

              Row(
                children: [
                  Text(
                  item.id,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                  SizedBox(
                    height: myHeight * 0.01,
                  ),
                  SizedBox(
                    width: myWidth * 0.03,
                  ),
                  Text(
                    item.marketCapChangePercentage24H.toStringAsFixed(2) + '%',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: item.marketCapChangePercentage24H >= 0
                            ? Colors.green
                            : Colors.red),
                  ),
                ],
              ),
              Text(
                '\$ '+ item.currentPrice.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
