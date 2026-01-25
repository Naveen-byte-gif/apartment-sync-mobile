import '../../../../core/imports/app_imports.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/story_provider.dart';
import 'widgets/news_list_view.dart';
import 'widgets/news_tab_bar.dart';
import 'widgets/story_list_view.dart';

class NewsTabScreen extends StatefulWidget {
  const NewsTabScreen({super.key});

  @override
  State<NewsTabScreen> createState() => _NewsTabScreenState();
}

class _NewsTabScreenState extends State<NewsTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final news = context.read<NewsProvider>();
      news.loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            NewsTabBar(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Consumer<NewsProvider>(
                    builder: (context, news, _) {
                      return NewsListView(
                        articles: news.sportsNews,
                        isLoading: news.isLoading,
                        onRefresh: news.loadAll,
                        category: 'Sports',
                      );
                    },
                  ),
                  Consumer<StoryProvider>(
                    builder: (context, storyProvider, _) {
                      return StoryListView(
                        stories: storyProvider.stories,
                        isLoading: storyProvider.isLoading,
                        isGenerating: storyProvider.isGenerating,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
