import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/chartModel.dart';
import 'package:my_crypto/View/Components/outlook_card.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:my_crypto/theme/app_theme.dart';

void main() {
  testWidgets(
      'shows disclaimer and indicator summary without large-text overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: OutlookCard(
              chartData: _chartData(),
              isLoading: false,
              hasError: false,
              timeframe: '1M',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Technical outlook'), findsOneWidget);
    expect(
      find.text(
        'Rule-based indicators on past prices. Not AI, not financial advice, no guarantee.',
      ),
      findsOneWidget,
    );
    expect(_summaryTextFinder(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the insufficient-history empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: OutlookCard(
              chartData: [],
              isLoading: false,
              hasError: false,
              timeframe: '1D',
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Not enough price history for this timeframe'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error without indicator summary when data failed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: OutlookCard(
              chartData: _chartData(),
              isLoading: false,
              hasError: true,
              timeframe: '1M',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Technical outlook unavailable'), findsOneWidget);
    expect(_summaryTextFinder(), findsNothing);
    expect(find.text('RSI (14)'), findsNothing);
    expect(find.byType(SkeletonShimmer), findsNothing);
  });

  testWidgets('shows loading skeletons without indicator rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: OutlookCard(
              chartData: _chartData(),
              isLoading: true,
              hasError: false,
              timeframe: '1M',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SkeletonShimmer), findsWidgets);
    expect(find.text('RSI (14)'), findsNothing);
    expect(_summaryTextFinder(), findsNothing);
    expect(find.text('Technical outlook unavailable'), findsNothing);
  });
}

Finder _summaryTextFinder() => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'\d+ of \d+ indicators').hasMatch(widget.data ?? ''),
    );

List<ChartModel> _chartData() => List.generate(
      40,
      (index) => ChartModel(
        time: DateTime(2024).millisecondsSinceEpoch + index * 3600000,
        open: 100 + index * 0.5,
        close: 100 + index * 0.5,
      ),
    );
