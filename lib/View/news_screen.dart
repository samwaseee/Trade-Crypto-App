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
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8.0), // Rounded corners for the image
                      child: SizedBox(
                        width: 100, // Set the width
                        height: 80, // Set the height
                        child: Image.network(
                          article.imageUrl!,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        : const Icon(Icons.image, size: 100, color: Colors.grey),
                    title: Text(
                      article.title ?? 'No Title',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Click to read more...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xffFBC700),
                      size: 20.0,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: BorderSide(color: Color(0xffFBC700), width: 1),
                    ),
                    onTap: () => _launchURL(article.link ?? ''),
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
