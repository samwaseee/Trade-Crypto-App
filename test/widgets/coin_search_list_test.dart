import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coin_search_result.dart';
import 'package:my_crypto/View/Components/coin_search_list.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:my_crypto/theme/app_theme.dart';

void main() {
  testWidgets('ErrorState scrolls instead of overflowing with large text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 180,
                child: ErrorState(
                  message:
                      'Could not load your watchlist. Check your connection and try again.',
                  onRetry: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('debounces search and aborts stale requests', (tester) async {
    final firstResponse = Completer<List<CoinSearchResult>>();
    final requests = <String>[];
    var firstRequestAborted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CoinSearchList(
            marketCoins: const [],
            onRefresh: () async {},
            onResultSelected: (_) {},
            coinTileBuilder: (_) => const SizedBox.shrink(),
            search: (query, {abortTrigger}) {
              requests.add(query);
              if (query == 'bit') {
                abortTrigger!.then((_) => firstRequestAborted = true);
                return firstResponse.future;
              }
              return Future.value([
                const CoinSearchResult(
                  id: 'bitcoin',
                  name: 'Bitcoin',
                  symbol: 'btc',
                  image: '',
                  marketCapRank: 1,
                ),
              ]);
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bit');
    await tester.pump(const Duration(milliseconds: 399));
    expect(requests, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(requests, ['bit']);

    await tester.enterText(find.byType(TextField), 'bitcoin');
    await tester.pump();
    expect(firstRequestAborted, isTrue);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(requests, ['bit', 'bitcoin']);
    expect(find.text('Bitcoin'), findsOneWidget);

    firstResponse.complete([
      const CoinSearchResult(
        id: 'stale',
        name: 'Stale result',
        symbol: 'old',
        image: '',
        marketCapRank: null,
      ),
    ]);
    await tester.pump();
    expect(find.text('Stale result'), findsNothing);
  });
}
