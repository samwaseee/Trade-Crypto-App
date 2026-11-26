import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';
import 'package:my_crypto/View/trade_history_screen.dart';
import 'package:my_crypto/theme/app_theme.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PortfolioRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = PortfolioRepository(firestore: firestore);
  });

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TradeHistoryScreen(
          userId: 'user-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state when there are no closed trades',
      (tester) async {
    await pumpHistory(tester);

    expect(find.text('No closed trades yet.'), findsOneWidget);
    expect(find.text('+\$0.00'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
  });

  testWidgets('shows a closed trade row with side, status, and signed P&L',
      (tester) async {
    await firestore
        .collection('users')
        .doc('user-1')
        .collection('closedTrades')
        .doc('trade-1')
        .set({
      'type': 'Buy',
      'coinId': 'bitcoin',
      'coinName': 'Bitcoin',
      'coinSymbol': 'btc',
      'coinImage': '',
      'amount': 1,
      'entryPrice': 100,
      'exitPrice': 110,
      'cost': 100,
      'realizedPnl': 10,
      'closeReason': 'liquidated',
      'openedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'closedAt': Timestamp.fromMillisecondsSinceEpoch(0),
    });

    await pumpHistory(tester);

    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('LONG'), findsOneWidget);
    expect(find.text('Liquidated'), findsOneWidget);
    expect(find.text('Realized +\$10.00'), findsOneWidget);
    expect(find.text('+10.00%'), findsOneWidget);
    expect(find.text('Closed just now'), findsOneWidget);
  });
}
