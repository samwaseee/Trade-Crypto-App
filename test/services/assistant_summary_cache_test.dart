import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Model/article.dart';
import 'package:my_crypto/Services/assistant_service.dart';

void main() {
  test('summary cache expires after ten minutes and keys article content', () {
    var now = DateTime(2026, 11, 26, 12);
    final cache = AssistantSummaryCache(clock: () => now);
    final articles = [
      Article(
        title: 'Bitcoin moves higher',
        description: 'The price rose today.',
        link: null,
        imageUrl: null,
      ),
    ];

    expect(cache.get(articles), isNull);
    cache.put(articles, '- Summary\nOverall sentiment: Bullish');
    expect(cache.get(articles), '- Summary\nOverall sentiment: Bullish');
    expect(
      cache.get([
        Article(
          title: 'Bitcoin moves higher',
          description: 'A different description.',
          link: null,
          imageUrl: null,
        ),
      ]),
      isNull,
    );

    now = now.add(const Duration(minutes: 9, seconds: 59));
    expect(cache.get(articles), '- Summary\nOverall sentiment: Bullish');
    now = now.add(const Duration(seconds: 1));
    expect(cache.get(articles), isNull);
  });
}
