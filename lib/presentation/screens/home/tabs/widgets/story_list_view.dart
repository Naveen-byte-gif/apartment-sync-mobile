import '../../../../../core/imports/app_imports.dart';
import '../../../../../data/models/telugu_story.dart';
import '../../../../providers/tts_provider.dart';
import '../story_detail_screen.dart';
import 'story_card.dart';
import 'story_generation_widget.dart';

class StoryListView extends StatelessWidget {
  final List<TeluguStory> stories;
  final bool isLoading;
  final bool isGenerating;

  const StoryListView({
    super.key,
    required this.stories,
    required this.isLoading,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        if (isLoading && stories.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        return Column(
          children: [
            // Story Generation Widget
            StoryGenerationWidget(),

            // Stories List
            Expanded(
              child: stories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'కథలు లేవు',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'పైన ఉన్న బటన్ నొక్కి కొత్త కథను సృష్టించండి',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        // Refresh can regenerate a story
                      },
                      color: AppColors.primary,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ...stories.map(
                            (story) => StoryCard(
                              story: story,
                              onTap: () {
                                // Navigate to detail screen
                                _navigateToDetail(context, story);
                                // Auto-start reading when opening detail (optional)
                                // Uncomment below if you want auto-read on open
                                // WidgetsBinding.instance.addPostFrameCallback((_) {
                                //   final ttsProvider = context.read<TtsProvider>();
                                //   ttsProvider.speakStory(
                                //     storyId: story.id,
                                //     title: story.title,
                                //     content: story.content,
                                //     moral: story.moral,
                                //   );
                                // });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, TeluguStory story) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)),
    );
  }
}
