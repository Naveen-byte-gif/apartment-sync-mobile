import '../../../../core/imports/app_imports.dart';
import '../../../../data/models/telugu_story.dart';
import '../../../../core/constants/story_api_constants.dart';
import '../../../providers/tts_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryDetailScreen extends StatefulWidget {
  final TeluguStory story;

  const StoryDetailScreen({
    super.key,
    required this.story,
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-read story when opened (optional - can be removed if not needed)
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final ttsProvider = context.read<TtsProvider>();
    //   ttsProvider.speakStory(
    //     storyId: widget.story.id,
    //     title: widget.story.title,
    //     content: widget.story.content,
    //     moral: widget.story.moral,
    //   );
    // });
  }

  @override
  void dispose() {
    // Don't stop TTS on dispose - let user control it
    super.dispose();
  }

  Future<void> _toggleReadAloud(TtsProvider ttsProvider) async {
    final isReading = ttsProvider.isStoryBeingRead(widget.story.id);
    
    if (isReading) {
      await ttsProvider.stop();
    } else {
      await ttsProvider.speakStory(
        storyId: widget.story.id,
        title: widget.story.title,
        content: widget.story.content,
        moral: widget.story.moral,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('కథ'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        actions: [
          Consumer<TtsProvider>(
            builder: (context, ttsProvider, _) {
              final isReading = ttsProvider.isStoryBeingRead(widget.story.id);
              return IconButton(
                icon: Icon(isReading ? Icons.stop : Icons.volume_up),
                onPressed: () => _toggleReadAloud(ttsProvider),
                tooltip: isReading ? 'ఆపు' : 'చదవండి',
              );
            },
          ),
        ],
      ),
      body: Consumer<TtsProvider>(
        builder: (context, ttsProvider, _) {
          final isReading = ttsProvider.isStoryBeingRead(widget.story.id);
          
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                StoryApiConstants.getCategoryLabel(widget.story.category),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Story Image
            if (widget.story.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.story.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Title
            Text(
              widget.story.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            
            // Story Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.story.content,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  height: 1.8,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 24),
            
            // Moral Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: AppColors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'నీతి',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.story.moral,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Story Info
            Row(
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.story.wordCount} పదాలు',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(widget.story.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
                  ],
                ),
              ),
              // Floating Read Button
              if (!isReading)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton.extended(
                    onPressed: () => _toggleReadAloud(ttsProvider),
                    backgroundColor: AppColors.primary,
                    icon: const Icon(Icons.volume_up, color: Colors.white),
                    label: const Text(
                      'చదవండి',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: () => _toggleReadAloud(ttsProvider),
                    backgroundColor: AppColors.error,
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} నిమిషాల క్రితం';
      }
      return '${difference.inHours} గంటల క్రితం';
    } else if (difference.inDays == 1) {
      return 'నిన్న';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} రోజుల క్రితం';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

