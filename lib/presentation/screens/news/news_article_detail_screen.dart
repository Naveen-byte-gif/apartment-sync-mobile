import 'package:url_launcher/url_launcher.dart';

import '../../../core/imports/app_imports.dart';
import '../../../data/models/news_article.dart';

class NewsArticleDetailScreen extends StatelessWidget {
  final NewsArticle article;

  const NewsArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(article.source ?? 'Article'),
        backgroundColor: AppColors.primary,
        actions: [
          if (article.url != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openInBrowser(article.url!),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  article.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (article.source != null)
              Text(
                article.source!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 16),
            if (article.description != null)
              Text(
                article.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (article.url != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openInBrowser(article.url!),
                  icon: const Icon(Icons.launch),
                  label: const Text('Read full article'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}


