import 'dart:async';
import 'dart:convert';

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

  static final http.Client _defaultClient = http.Client();

  final http.Client _client;
  final String _apiKey;

  Future<NewsResponse> fetchNews(String query) async {
    if (_apiKey.isEmpty) {
      throw const NewsException('News is not configured.');
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
    return NewsResponse(articles: news.articles.take(10).toList());
  }
}
