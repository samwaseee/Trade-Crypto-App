import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../Model/article.dart';

class NewsException implements Exception {
  const NewsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsService {
  NewsService({http.Client? client, String? apiKey})
      : _client = client ?? _defaultClient,
        _apiKey = apiKey ?? const String.fromEnvironment('NEWS_API_KEY');

  static const Duration _cacheDuration = Duration(minutes: 10);
  static final http.Client _defaultClient = http.Client();
  static final Map<String, _CachedNews> _cache = {};

  final http.Client _client;
  final String _apiKey;

  Future<NewsResponse> fetchNews(String query) async {
    if (_apiKey.isEmpty) {
      debugPrint(
        'NEWS_API_KEY is empty. Run with --dart-define-from-file=env.json '
        '(see README).',
      );
      throw NewsException(
        kDebugMode
            ? 'News API key is missing. Add NEWS_API_KEY to env.json, then run '
                'flutter run --dart-define-from-file=env.json.'
            : 'News is not configured.',
      );
    }

    final cacheKey = '$_apiKey\u0000$query';
    final now = DateTime.now();
    _cache.removeWhere(
      (_, cached) => now.difference(cached.cachedAt) >= _cacheDuration,
    );
    final cached = _cache[cacheKey];
    if (cached != null) {
      return _copyResponse(cached.response);
    }

    final uri = Uri.https('newsdata.io', '/api/1/news', {
      'apikey': _apiKey,
      'q': query,
      'language': 'en',
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const NewsException('News request timed out. Please try again.');
    }

    if (response.statusCode != 200) {
      throw const NewsException(
        'Unable to load news right now. Please try again.',
      );
    }

    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final news = NewsResponse.fromJson(data);
    final result = NewsResponse(articles: news.articles.take(10).toList());
    _cache[cacheKey] = _CachedNews(result, DateTime.now());
    return _copyResponse(result);
  }

  static NewsResponse _copyResponse(NewsResponse response) =>
      NewsResponse(articles: List<Article>.of(response.articles));
}

class _CachedNews {
  const _CachedNews(this.response, this.cachedAt);

  final NewsResponse response;
  final DateTime cachedAt;
}
