import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Model/article.dart';

class NewsService {
  static const String _baseEndpoint = 'https://newsdata.io/api/1/news?apikey=pub_62343116c4080eb34f4e0ab298cadb1be2715';

  Future<NewsResponse> fetchNews(String query) async {
    final response = await http.get(
      Uri.parse('$_baseEndpoint&q=$query'),
    );

    if (response.statusCode == 200) {
      return NewsResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load news');
    }
  }
}
