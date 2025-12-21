import '../../../../../core/imports/app_imports.dart';
import '../../../../../core/constants/story_api_constants.dart';
import '../story_detail_screen.dart';

class StoryGenerationWidget extends StatefulWidget {
  const StoryGenerationWidget({super.key});

  @override
  State<StoryGenerationWidget> createState() => _StoryGenerationWidgetState();
}

class _StoryGenerationWidgetState extends State<StoryGenerationWidget> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = StoryApiConstants.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryProvider>(
      builder: (context, storyProvider, _) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'కొత్త కథను సృష్టించండి',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'కథ వర్గాన్ని ఎంచుకోండి:',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: StoryApiConstants.categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(
                      StoryApiConstants.getCategoryLabel(category),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: storyProvider.isGenerating
                          ? null
                          : () async {
                              final story = await storyProvider
                                  .generateRandomStory();
                              if (story != null && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StoryDetailScreen(story: story),
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'కథను సృష్టించడంలో లోపం ఉంది',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('యాదృచ్ఛిక కథ'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: storyProvider.isGenerating
                          ? null
                          : () async {
                              if (_selectedCategory != null) {
                                final story = await storyProvider.generateStory(
                                  _selectedCategory!,
                                );
                                if (story != null && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StoryDetailScreen(story: story),
                                    ),
                                  );
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'కథను సృష్టించడంలో లోపం ఉంది',
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: storyProvider.isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textOnPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.add_circle_outline),
                      label: Text(
                        storyProvider.isGenerating
                            ? 'సృష్టిస్తోంది...'
                            : 'కథను సృష్టించండి',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
