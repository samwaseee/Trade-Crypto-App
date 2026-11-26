import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_crypto/Model/coin_search_result.dart';
import 'package:my_crypto/Services/market_repository.dart';

void main() {
  group('CoinGecko search', () {
    test('parses search results and caches the query', () async {
      var requestCount = 0;
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestCount++;
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'coins': [
              {
                'id': 'bitcoin',
                'name': 'Bitcoin',
                'symbol': 'btc',
                'market_cap_rank': 1,
                'thumb': 'https://example.com/thumb.png',
                'large': 'https://example.com/large.png',
              },
            ],
          }),
          200,
        );
      });
      final repository = MarketRepository(client: client);

      final results = await repository.searchCoins('  Bitcoin ');
      final cachedResults = await repository.searchCoins('bitcoin');

      expect(requestedUri!.host, 'api.coingecko.com');
      expect(requestedUri!.path, '/api/v3/search');
      expect(requestedUri!.queryParameters, {'query': 'Bitcoin'});
      expect(results.single.id, 'bitcoin');
      expect(results.single.name, 'Bitcoin');
      expect(results.single.symbol, 'btc');
      expect(results.single.marketCapRank, 1);
      expect(results.single.image, 'https://example.com/large.png');
      expect(cachedResults.single.id, 'bitcoin');
      expect(requestCount, 1);
    });

    test('rejects malformed search data as BadData', () async {
      final client = MockClient(
        (_) async => http.Response('{"coins":[{"id":"bitcoin"}]}', 200),
      );
      final repository = MarketRepository(client: client);

      await expectLater(
        repository.searchCoins('bitcoin'),
        throwsA(isA<BadData>()),
      );
    });

    test('maps rate limits and connection errors to typed errors', () async {
      final rateLimited = MarketRepository(
        client: MockClient((_) async => http.Response('limited', 429)),
      );
      await expectLater(
        rateLimited.searchCoins('bitcoin'),
        throwsA(isA<RateLimited>()),
      );

      final offline = MarketRepository(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        offline.searchCoins('bitcoin'),
        throwsA(isA<Offline>()),
      );
    });

    test('parses a search result into the existing detail model', () {
      final result = CoinSearchResult.fromJson({
        'id': 'ethereum',
        'name': 'Ethereum',
        'symbol': 'eth',
        'market_cap_rank': 2,
        'thumb': 'https://example.com/eth.png',
      });

      final coin = result.toCoinModel();

      expect(coin.id, 'ethereum');
      expect(coin.name, 'Ethereum');
      expect(coin.symbol, 'eth');
      expect(coin.image, 'https://example.com/eth.png');
      expect(coin.marketCapRank, 2);
    });
  });
}
