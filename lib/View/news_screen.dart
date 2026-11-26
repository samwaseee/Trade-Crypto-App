import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Model/article.dart';
import '../Services/assistant_service.dart';
import '../Services/news_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<NewsResponse> futureNews;
  final AssistantService _assistantService = AssistantService();
  bool _summarizing = false;

  @override
  void initState() {
    super.initState();
    futureNews = NewsService().fetchNews("cryptocurrency");
  }

  Future<void> _refreshNews() async {
    setState(() {
      futureNews = NewsService().fetchNews('cryptocurrency');
    });
    await futureNews;
  }

  Future<void> _showSummary(List<Article> articles) async {
    setState(() => _summarizing = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _NewsSummarySheet(
          articles: articles,
          assistantService: _assistantService,
          userId: FirebaseAuth.instance.currentUser?.uid,
        ),
      );
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latest News'),
        actions: [
          FutureBuilder<NewsResponse>(
            future: futureNews,
            builder: (context, snapshot) {
              final articles = snapshot.data?.articles;
              if (articles == null || articles.isEmpty) {
                return const SizedBox.shrink();
              }
              return TextButton.icon(
                onPressed: _summarizing
                    ? null
                    : () => _showSummary(articles),
                icon: _summarizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.summarize_outlined),
                label: Text(_summarizing ? 'Summarizing' : 'Summarize'),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNews,
        child: FutureBuilder<NewsResponse>(
          future: futureNews,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const NewsListSkeleton();
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: ErrorState(
                      error: snapshot.error,
                      message: snapshot.error is NewsException
                          ? (snapshot.error! as NewsException).message
                          : null,
                      onRetry: _refreshNews,
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData || snapshot.data!.articles.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: const EmptyState(message: 'No news articles found.'),
                  ),
                ],
              );
            }

            final articles = snapshot.data!.articles;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _launchURL(article.link ?? ''),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: SizedBox(
                              width: 90,
                              height: 70,
                              child: article.imageUrl != null
                                  ? Image.network(
                                      article.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        child: Icon(
                                          Icons.newspaper,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.newspaper,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.title ?? 'No Title',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Click to read more...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
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

class _NewsSummarySheet extends StatefulWidget {
  const _NewsSummarySheet({
    required this.articles,
    required this.assistantService,
    required this.userId,
  });

  final List<Article> articles;
  final AssistantService assistantService;
  final String? userId;

  @override
  State<_NewsSummarySheet> createState() => _NewsSummarySheetState();
}

class _NewsSummarySheetState extends State<_NewsSummarySheet> {
  late Future<String> _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    _summary = widget.assistantService.summarizeNews(
      widget.articles,
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('News summary', style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close summary',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder<String>(
                  future: _summary,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorState(
                        error: snapshot.error,
                        message: snapshot.error is AssistantException
                            ? (snapshot.error! as AssistantException).message
                            : null,
                        onRetry: () => setState(_loadSummary),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      child: MarkdownBody(
                        data: snapshot.data!,
                        styleSheet: MarkdownStyleSheet(
                          p: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
