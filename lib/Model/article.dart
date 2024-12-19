import 'dart:convert';

class Article {
  final String? title;
  final String? link;
  final String? imageUrl;

  Article({
    required this.title,
    required this.link,
    required this.imageUrl,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] as String?,
      link: json['link'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class NewsResponse {
  final List<Article> articles;

  NewsResponse({required this.articles});

  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    var list = json['results'] as List;
    List<Article> articlesList = list.map((i) => Article.fromJson(i)).toList();
    return NewsResponse(articles: articlesList);
  }
}
