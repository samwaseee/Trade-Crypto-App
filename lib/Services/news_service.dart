import 'package:cloud_functions/cloud_functions.dart';

import '../Model/article.dart';

class NewsService {
  Future<NewsResponse> fetchNews(String query) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('getNews');
    final result = await callable.call({'query': query});
    final data = Map<String, dynamic>.from(result.data as Map);
    return NewsResponse.fromJson(data);
  }
}
