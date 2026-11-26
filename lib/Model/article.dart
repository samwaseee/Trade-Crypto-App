class Article {
  final String? title;
  final String? link;
  final String? imageUrl;
  final String? description;

  Article({
    required this.title,
    required this.link,
    required this.imageUrl,
    this.description,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] as String?,
      link: json['link'] as String?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
    );
  }
}

class NewsResponse {
  final List<Article> articles;

  NewsResponse({required this.articles});

  factory NewsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['results'] as List;
    final articlesList = list
        .map((item) => Article.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return NewsResponse(articles: articlesList);
  }
}
