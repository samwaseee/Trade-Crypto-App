import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../Model/article.dart';

class NewsService {
  Future<NewsResponse> fetchNews(String query) async {
    final apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
    final url = 'https://newsdata.io/api/1/news?apikey=$apiKey&q=$query';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return NewsResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load news');
    }
  }
}
