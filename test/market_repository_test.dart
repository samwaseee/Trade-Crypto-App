import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_crypto/Services/market_repository.dart';

void main() {
  group('MarketRepository Typed Errors and MockClient Tests', () {
    test('HTTP 429 throws RateLimited', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Too Many Requests', 429);
      });

      final repo = MarketRepository(client: mockClient);

      expect(() => repo.getMarkets(force: true), throwsA(isA<RateLimited>()));
    });

    test('HTTP 500 throws ServerError', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final repo = MarketRepository(client: mockClient);

      expect(() => repo.getMarkets(force: true), throwsA(isA<ServerError>()));
    });

    test('SocketException throws Offline', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      final repo = MarketRepository(client: mockClient);

      expect(() => repo.getMarkets(force: true), throwsA(isA<Offline>()));
    });

    test('HTTP 200 with invalid JSON throws BadData', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final repo = MarketRepository(client: mockClient);

      expect(() => repo.getMarkets(force: true), throwsA(isA<BadData>()));
    });

    test('HTTP 200 with valid minimal JSON returns coins', () async {
      final jsonBody = '''
      [
        {
          "id": "bitcoin",
          "symbol": "btc",
          "name": "Bitcoin",
          "image": "https://example.com/btc.png",
          "current_price": 50000.0,
          "market_cap_rank": 1,
          "total_volume": 1000000.0,
          "high_24h": 52000.0,
          "low_24h": 48000.0,
          "price_change_24h": 1000.0,
          "market_cap_change_percentage_24h": 2.5,
          "sparkline_in_7d": {
            "price": [48000.0, 50000.0]
          }
        }
      ]
      ''';

      final mockClient = MockClient((request) async {
        return http.Response(jsonBody, 200);
      });

      final repo = MarketRepository(client: mockClient);
      final coins = await repo.getMarkets(force: true);

      expect(coins.length, equals(1));
      expect(coins[0].id, equals('bitcoin'));
      expect(coins[0].currentPrice, equals(50000.0));
    });

    test('500 then immediate second call: rethrows ServerError and calls == 1', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response('Error', 500);
      });

      final repo = MarketRepository(client: mockClient);

      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<ServerError>()));
      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<ServerError>()));
      expect(calls, equals(1));
    });

    test('429 then immediate second call: both throw RateLimited and calls == 1', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response('Rate Limited', 429);
      });

      final repo = MarketRepository(client: mockClient);

      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<RateLimited>()));
      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<RateLimited>()));
      expect(calls, equals(1));
    });

    test('Valid JSON then immediate getMarkets(force: true): second call returns cached coins and calls == 1', () async {
      var calls = 0;
      final jsonBody = '[{"id": "bitcoin", "symbol": "btc", "name": "Bitcoin", "image": "img", "current_price": 50000.0, "market_cap_rank": 1, "total_volume": 100.0, "high_24h": 51.0, "low_24h": 49.0, "price_change_24h": 1.0, "market_cap_change_percentage_24h": 1.0, "sparkline_in_7d": {"price": [1.0, 2.0]}}]';
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response(jsonBody, 200);
      });

      final repo = MarketRepository(client: mockClient);
      final coins1 = await repo.getMarkets(force: true);
      final coins2 = await repo.getMarkets(force: true);

      expect(coins1.length, equals(1));
      expect(coins2.length, equals(1));
      expect(calls, equals(1));
    });

    test('MockClient throwing ClientException -> Offline', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('x');
      });

      final repo = MarketRepository(client: mockClient);
      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<Offline>()));
    });

    test('MockClient throwing TimeoutException -> Offline', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('x');
      });

      final repo = MarketRepository(client: mockClient);
      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<Offline>()));
    });

    test('MockClient throwing StateError -> Unexpected', () async {
      final mockClient = MockClient((request) async {
        throw StateError('x');
      });

      final repo = MarketRepository(client: mockClient);
      await expectLater(() => repo.getMarkets(force: true), throwsA(isA<Unexpected>()));
    });
  });

  group('MarketRepository getOhlc Tests', () {
    test('valid OHLC JSON [[1700000000000,1.0,2.0,0.5,1.5]] -> getOhlc returns 1 item', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response('[[1700000000000,1.0,2.0,0.5,1.5]]', 200);
      });

      final repo = MarketRepository(client: mockClient);
      final ohlc = await repo.getOhlc('bitcoin', 30);

      expect(ohlc.length, equals(1));
      expect(ohlc[0].time, equals(1700000000000));
      expect(ohlc[0].open, equals(1.0));
      expect(ohlc[0].high, equals(2.0));
      expect(ohlc[0].low, equals(0.5));
      expect(ohlc[0].close, equals(1.5));
      expect(calls, equals(1));
    });

    test('two sequential calls for the same key -> calls == 1', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response('[[1700000000000,1.0,2.0,0.5,1.5]]', 200);
      });

      final repo = MarketRepository(client: mockClient);
      final ohlc1 = await repo.getOhlc('bitcoin', 30);
      final ohlc2 = await repo.getOhlc('bitcoin', 30);

      expect(ohlc1.length, equals(1));
      expect(ohlc2.length, equals(1));
      expect(calls, equals(1));
    });

    test('Future.wait of two concurrent calls for the same key -> calls == 1', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        return http.Response('[[1700000000000,1.0,2.0,0.5,1.5]]', 200);
      });

      final repo = MarketRepository(client: mockClient);
      final results = await Future.wait([
        repo.getOhlc('bitcoin', 30),
        repo.getOhlc('bitcoin', 30),
      ]);

      expect(results[0].length, equals(1));
      expect(results[1].length, equals(1));
      expect(calls, equals(1));
    });

    test('429 -> RateLimited; 500 -> ServerError; invalid JSON body with 200 -> BadData; ClientException -> Offline', () async {
      // 429 -> RateLimited
      {
        var calls = 0;
        final mockClient = MockClient((request) async {
          calls++;
          return http.Response('Rate Limited', 429);
        });
        final repo = MarketRepository(client: mockClient);
        await expectLater(() => repo.getOhlc('bitcoin', 30), throwsA(isA<RateLimited>()));
        expect(calls, equals(1));
      }

      // 500 -> ServerError
      {
        var calls = 0;
        final mockClient = MockClient((request) async {
          calls++;
          return http.Response('Server Error', 500);
        });
        final repo = MarketRepository(client: mockClient);
        await expectLater(() => repo.getOhlc('bitcoin', 30), throwsA(isA<ServerError>()));
        expect(calls, equals(1));
      }

      // invalid JSON body with 200 -> BadData
      {
        var calls = 0;
        final mockClient = MockClient((request) async {
          calls++;
          return http.Response('invalid json body', 200);
        });
        final repo = MarketRepository(client: mockClient);
        await expectLater(() => repo.getOhlc('bitcoin', 30), throwsA(isA<BadData>()));
        expect(calls, equals(1));
      }

      // ClientException -> Offline
      {
        var calls = 0;
        final mockClient = MockClient((request) async {
          calls++;
          throw http.ClientException('No network');
        });
        final repo = MarketRepository(client: mockClient);
        await expectLater(() => repo.getOhlc('bitcoin', 30), throwsA(isA<Offline>()));
        expect(calls, equals(1));
      }
    });
  });
}
