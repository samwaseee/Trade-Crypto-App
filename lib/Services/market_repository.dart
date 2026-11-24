import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../Model/coinModel.dart';

class MarketRepository {
  MarketRepository._internal();
  static final MarketRepository instance = MarketRepository._internal();

  List<CoinModel>? _cachedCoins;
  DateTime? _lastUpdated;
  Future<List<CoinModel>>? _inFlightFuture;
  DateTime? _lastAttemptTime;
  int _failures = 0;

  final Map<String, double> _priceCache = {};
  final Map<String, DateTime> _priceCacheTime = {};
  final Map<String, Future<double>> _inFlightPrices = {};
  int _priceFailures = 0;
  DateTime? _lastPriceAttemptTime;

  DateTime? get lastUpdated => _lastUpdated;

  bool get isStale {
    if (_cachedCoins == null) return false;
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!).inSeconds >= 60;
  }

  Future<List<CoinModel>> getMarkets({bool force = false}) async {
    final now = DateTime.now();

    // 1. If a request is already in flight, return that same Future
    if (_inFlightFuture != null) {
      return _inFlightFuture!;
    }

    // 2. Fresh cache return when force is false and cache is under 60 seconds old
    if (!force && _cachedCoins != null && _lastUpdated != null) {
      if (now.difference(_lastUpdated!).inSeconds < 60) {
        return _cachedCoins!;
      }
    }

    // 3. Back-off after failures check (regardless of force)
    if (_lastAttemptTime != null && _failures > 0) {
      final backoffSeconds = min(60, 10 * pow(2, _failures - 1).toInt());
      if (now.difference(_lastAttemptTime!).inSeconds < backoffSeconds) {
        if (_cachedCoins != null) {
          return _cachedCoins!;
        }
        throw Exception('Market data unavailable (rate limited). Please try again in a minute.');
      }
    }

    // 4. Minimum 10-second interval between API calls to ALL callers (regardless of force)
    if (_lastAttemptTime != null) {
      if (now.difference(_lastAttemptTime!).inSeconds < 10) {
        if (_cachedCoins != null) {
          return _cachedCoins!;
        }
        throw Exception('Market data unavailable (rate limited). Please try again in a minute.');
      }
    }

    _lastAttemptTime = now;
    _inFlightFuture = _fetchMarketsApi();

    try {
      final result = await _inFlightFuture!;
      return result;
    } finally {
      _inFlightFuture = null;
    }
  }

  Future<List<CoinModel>> _fetchMarketsApi() async {
    const url = 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&sparkline=true';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      });

      if (response.statusCode == 200) {
        final coins = coinModelFromJson(response.body);
        _cachedCoins = coins;
        _lastUpdated = DateTime.now();
        _failures = 0;
        return coins;
      } else {
        _failures = min(10, _failures + 1);
        if (_cachedCoins != null) {
          return _cachedCoins!;
        }
        throw Exception('Market data unavailable (rate limited). Please try again in a minute.');
      }
    } catch (e) {
      _failures = min(10, _failures + 1);
      if (_cachedCoins != null) {
        return _cachedCoins!;
      }
      throw Exception('Market data unavailable (rate limited). Please try again in a minute.');
    }
  }

  Future<double> getFreshPrice(String coinId) async {
    final now = DateTime.now();

    // 1. In-flight de-duplication per coin
    if (_inFlightPrices.containsKey(coinId)) {
      return _inFlightPrices[coinId]!;
    }

    // 2. Cache each coin's price for 10 seconds
    if (_priceCache.containsKey(coinId) && _priceCacheTime.containsKey(coinId)) {
      if (now.difference(_priceCacheTime[coinId]!).inSeconds < 10) {
        return _priceCache[coinId]!;
      }
    }

    // 3. Back-off after failures check
    if (_lastPriceAttemptTime != null && _priceFailures > 0) {
      final backoffSeconds = min(60, 10 * pow(2, _priceFailures - 1).toInt());
      if (now.difference(_lastPriceAttemptTime!).inSeconds < backoffSeconds) {
        return _getFallbackPrice(coinId);
      }
    }

    _lastPriceAttemptTime = now;
    final future = _fetchFreshPriceApi(coinId);
    _inFlightPrices[coinId] = future;

    try {
      final price = await future;
      return price;
    } catch (e) {
      return _getFallbackPrice(coinId);
    } finally {
      _inFlightPrices.remove(coinId);
    }
  }

  Future<double> _fetchFreshPriceApi(String coinId) async {
    final url = 'https://api.coingecko.com/api/v3/simple/price?ids=${Uri.encodeQueryComponent(coinId)}&vs_currencies=usd';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final usdPrice = data[coinId]?['usd'];
        if (usdPrice != null) {
          final price = (usdPrice as num).toDouble();
          if (price.isFinite && price > 0) {
            _priceCache[coinId] = price;
            _priceCacheTime[coinId] = DateTime.now();
            _priceFailures = 0;
            return price;
          }
        }
      }
    } catch (_) {}

    _priceFailures = min(10, _priceFailures + 1);
    return _getFallbackPrice(coinId);
  }

  double _getFallbackPrice(String coinId) {
    if (_cachedCoins != null && _lastUpdated != null) {
      if (DateTime.now().difference(_lastUpdated!).inSeconds < 60) {
        final match = _cachedCoins!.firstWhere(
          (c) => c.id == coinId,
          orElse: () => CoinModel(
            id: '',
            symbol: '',
            name: '',
            image: '',
            currentPrice: -1,
            marketCapRank: 0,
            totalVolume: 0,
            high24H: 0,
            low24H: 0,
            priceChange24H: 0,
            marketCapChangePercentage24H: 0,
            sparklineIn7D: SparklineIn7D(price: []),
          ),
        );
        if (match.currentPrice.isFinite && match.currentPrice > 0) {
          return match.currentPrice;
        }
      }
    }
    throw Exception('Could not get a current price. Please try again.');
  }
}
