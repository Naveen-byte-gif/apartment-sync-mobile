import '../../../core/imports/app_imports.dart';
import '../../providers/news_provider.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/cricket_match.dart';
import 'news_article_detail_screen.dart';

class NewsHomeScreen extends StatefulWidget {
  const NewsHomeScreen({super.key});

  @override
  State<NewsHomeScreen> createState() => _NewsHomeScreenState();
}

class _NewsHomeScreenState extends State<NewsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final news = context.read<NewsProvider>();
      news.loadAll();
      news.loadCricket(startAutoRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('News & Cricket'),
        backgroundColor: AppColors.primary,
        actions: const [
          Icon(Icons.search),
          SizedBox(width: 12),
          Icon(Icons.notifications_none),
          SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'News'),
            Tab(text: 'Sports'),
            Tab(text: 'Cricket'),
          ],
        ),
      ),
      body: Consumer<NewsProvider>(
        builder: (context, news, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildAllTab(news),
              _buildNewsTab(news),
              _buildSportsTab(news),
              _buildCricketTab(news),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllTab(NewsProvider news) {
    if (news.isLoading && news.topNews.isEmpty) {
      return _buildNewsSkeletonList();
    }
    final featured = news.topNews.isNotEmpty ? news.topNews.first : null;
    final rest = news.topNews.skip(1).toList();
    return RefreshIndicator(
      onRefresh: news.loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (featured != null) _FeaturedNewsCard(article: featured),
          const SizedBox(height: 16),
          Text(
            'Latest News',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...rest.map((a) => _NewsListTile(article: a)).toList(),
        ],
      ),
    );
  }

  Widget _buildNewsTab(NewsProvider news) {
    if (news.isLoading && news.topNews.isEmpty) {
      return _buildNewsSkeletonList();
    }
    return RefreshIndicator(
      onRefresh: news.loadAll,
      child: _NewsListView(articles: news.topNews),
    );
  }

  Widget _buildSportsTab(NewsProvider news) {
    if (news.isLoading && news.sportsNews.isEmpty) {
      return _buildNewsSkeletonList();
    }
    return RefreshIndicator(
      onRefresh: news.loadAll,
      child: _NewsListView(articles: news.sportsNews),
    );
  }

  Widget _buildCricketTab(NewsProvider news) {
    if (news.isCricketLoading && news.liveMatches.isEmpty) {
      return _buildCricketSkeleton();
    }
    return RefreshIndicator(
      onRefresh: news.loadCricket,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (news.liveMatches.isNotEmpty)
            _LiveMatchCard(match: news.liveMatches.first),
          const SizedBox(height: 16),
          Text(
            'Live Matches',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...news.liveMatches.skip(1).map(
                (m) => _CricketListTile(match: m),
              ),
          const SizedBox(height: 16),
          Text(
            'Upcoming Matches',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...news.upcomingMatches.map(
            (m) => _CricketListTile(match: m),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildCricketSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}

class _NewsListView extends StatelessWidget {
  final List<NewsArticle> articles;

  const _NewsListView({required this.articles});

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return Center(
        child: Text(
          'No articles available right now.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        return _NewsListTile(article: articles[index]);
      },
    );
  }
}

class _FeaturedNewsCard extends StatelessWidget {
  final NewsArticle article;

  const _FeaturedNewsCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsArticleDetailScreen(article: article),
          ),
        );
      },
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: article.imageUrl != null
                    ? Image.network(
                        article.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                      ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.source ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsListTile extends StatelessWidget {
  final NewsArticle article;

  const _NewsListTile({required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsArticleDetailScreen(article: article),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: article.imageUrl != null
                    ? Image.network(
                        article.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, size: 24),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, size: 24),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.source ?? '',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  final CricketMatch match;

  const _LiveMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${match.teamA} vs ${match.teamB}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (match.isIndiaMatch)
                const Text(
                  '🇮🇳',
                  style: TextStyle(fontSize: 20),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (match.score != null)
            Text(
              '${match.score}  •  ${match.overs ?? ''} ov',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          const SizedBox(height: 4),
          Text(
            match.status ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _CricketListTile extends StatelessWidget {
  final CricketMatch match;

  const _CricketListTile({required this.match});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sports_cricket,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${match.teamA} vs ${match.teamB}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (match.isIndiaMatch) const Text('🇮🇳'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (match.score != null)
                    Text(
                      '${match.score}  •  ${match.overs ?? ''} ov',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  if (match.status != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      match.status!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


