import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Model/article.dart';
import '../Services/news_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<NewsResponse> futureNews;

  @override
  void initState() {
    super.initState();
    futureNews = NewsService().fetchNews("cryptocurrency");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        centerTitle: true,
        title: Text('Latest News', style: TextStyle(color: Colors.black, fontSize: 24)),
      ),
      body: Center(
        child: FutureBuilder<NewsResponse>(
          future: futureNews,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.articles.length,
                itemBuilder: (context, index) {
                  final article = snapshot.data!.articles[index];
                  return ListTile(
                    leading: article.imageUrl != null
                        ? SizedBox(
                            width: 100, // Set the width
                            height: 80, // Set the height
                            child: Image.network(
                              article.imageUrl!,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.image, size: 100),
                    // Default icon if imageUrl is null

                    title: Text(article.title ?? 'No Title'),
                    // Default text if title is null
                    onTap: () => _launchURL(article.link ??
                        ''), // Provide an empty string if link is null
                  );
                },
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }

            return CircularProgressIndicator();
          },
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (url.isNotEmpty) {
      if (!await launchUrl(Uri.parse(url))) {
        throw 'Could not launch $url';
      }
    }
  }
}
