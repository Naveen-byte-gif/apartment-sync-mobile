import '../../../../../core/imports/app_imports.dart';
import '../../../../../data/models/news_article.dart';
import '../news_detail_screen.dart';
import 'news_card.dart';
import 'news_featured_card.dart';

class NewsListView extends StatelessWidget {
  final List<NewsArticle> articles;
  final bool isLoading;
  final VoidCallback onRefresh;
  final String category;

  const NewsListView({
    super.key,
    required this.articles,
    required this.isLoading,
    required this.onRefresh,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && articles.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No news available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final featured = articles.isNotEmpty ? articles.first : null;
    final rest = articles.skip(1).toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final crossAxisCount = isTablet ? 2 : 1;
          final childAspectRatio = isTablet ? 0.85 : 1.2;

          if (isTablet) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                if (index == 0 && featured != null) {
                  return NewsFeaturedCard(
                    article: article,
                    onTap: () => _navigateToDetail(context, article),
                  );
                }
                return NewsCard(
                  article: article,
                  onTap: () => _navigateToDetail(context, article),
                );
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (featured != null) ...[
                NewsFeaturedCard(
                  article: featured,
                  onTap: () => _navigateToDetail(context, featured),
                ),
                const SizedBox(height: 16),
              ],
              ...rest.map(
                (article) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NewsCard(
                    article: article,
                    onTap: () => _navigateToDetail(context, article),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToDetail(BuildContext context, NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(article: article),
      ),
    );
  }
}

