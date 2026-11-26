import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_crypto/Services/news_service.dart';

void main() {
  group('NewsService', () {
    test('fetches news and returns at most ten articles', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'results': List.generate(
              12,
              (index) => {
                'title': 'Article $index',
                'link': 'https://example.com/$index',
                'image_url': 'https://example.com/$index.png',
              },
            ),
          }),
          200,
        );
      });

      final response = await NewsService(
        client: client,
        apiKey: 'test-key',
      ).fetchNews('bitcoin');

      expect(requestedUri!.scheme, 'https');
      expect(requestedUri!.host, 'newsdata.io');
      expect(requestedUri!.path, '/api/1/news');
      expect(requestedUri!.queryParameters, {
        'apikey': 'test-key',
        'q': 'bitcoin',
        'language': 'en',
      });
      expect(response.articles, hasLength(10));
      expect(response.articles.first.title, 'Article 0');
    });

    test('throws a friendly exception for non-200 responses', () async {
      final client = MockClient(
        (_) async => http.Response('unavailable', 500),
      );

      await expectLater(
        NewsService(client: client, apiKey: 'test-key').fetchNews('bitcoin-error'),
        throwsA(
          isA<NewsException>().having(
            (error) => error.message,
            'message',
            'Unable to load news right now. Please try again.',
          ),
        ),
      );
    });

    test('throws when the API key is empty without making a request', () async {
      var requestSent = false;
      final client = MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      });

      await expectLater(
        NewsService(client: client, apiKey: '').fetchNews('bitcoin'),
        throwsA(
          isA<NewsException>().having(
            (error) => error.message,
            'message',
            'News API key is missing. Add NEWS_API_KEY to env.json, then run '
            'flutter run --dart-define-from-file=env.json.',
          ),
        ),
      );
      expect(requestSent, isFalse);
    });

    test('caches successful results across service instances', () async {
      var requestCount = 0;
      final firstClient = MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'results': [
              {'title': 'Cached article'},
            ],
          }),
          200,
        );
      });
      final secondClient = MockClient((_) async {
        requestCount++;
        return http.Response('{"results": []}', 200);
      });

      final firstResponse = await NewsService(
        client: firstClient,
        apiKey: 'cache-test-key',
      ).fetchNews('cache-test-query');
      final secondResponse = await NewsService(
        client: secondClient,
        apiKey: 'cache-test-key',
      ).fetchNews('cache-test-query');

      expect(requestCount, 1);
      expect(firstResponse.articles.single.title, 'Cached article');
      expect(secondResponse.articles.single.title, 'Cached article');
    });
  });
}
