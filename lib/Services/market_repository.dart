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
        _failures++;
        if (_cachedCoins != null) {
          return _cachedCoins!;
        }
        throw Exception('Market data unavailable (rate limited). Please try again in a minute.');
      }
    } catch (e) {
      _failures++;
      if (_cachedCoins != null) {
        return _cachedCoins!;
      }
      throw Exception('Market data unavailable (rate limited). Please try again in a minute.');
    }
  }
}
