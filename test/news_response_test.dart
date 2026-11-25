import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Model/article.dart';

void main() {
  test('NewsResponse converts object-keyed article maps', () {
    final response = NewsResponse.fromJson({
      'results': [
        <Object?, Object?>{
          'title': 'Market update',
          'link': 'https://example.com/market',
          'image_url': 'https://example.com/market.png',
        },
      ],
    });

    expect(response.articles, hasLength(1));
    expect(response.articles.single.title, 'Market update');
    expect(response.articles.single.link, 'https://example.com/market');
    expect(response.articles.single.imageUrl, 'https://example.com/market.png');
  });
}
