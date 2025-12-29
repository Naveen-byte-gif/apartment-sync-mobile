import '../../../core/imports/app_imports.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/complaint_data.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({super.key});

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  String _selectedCategory = 'Electrical';
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;
  List<File> _selectedImages = [];

  final List<String> _categories = [
    'Electrical',
    'Plumbing',
    'Carpentry',
    'Painting',
    'Cleaning',
    'Security',
    'Elevator',
    'Common Area',
    'Other'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Emergency'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subCategoryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    if (_selectedImages.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 images allowed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImagesFromGallery();
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      if (_selectedImages.length >= 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 4 images allowed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final remainingSlots = 4 - _selectedImages.length;
        final imagesToAdd = images.take(remainingSlots).toList();
        
        setState(() {
          _selectedImages.addAll(
            imagesToAdd.map((xFile) => File(xFile.path)),
          );
        });

        if (images.length > remainingSlots && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only ${remainingSlots} image(s) added. Maximum 4 images allowed.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      if (_selectedImages.length >= 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 4 images allowed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  Future<void> _submitComplaint() async {
    print('🖱️ [FLUTTER] Submit complaint button clicked');
    if (!_formKey.currentState!.validate()) {
      print('❌ [FLUTTER] Form validation failed');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images first if any
      List<ComplaintMedia>? mediaList;
      if (_selectedImages.isNotEmpty) {
        mediaList = [];
        for (var file in _selectedImages) {
          try {
            // TODO: Replace with generic upload endpoint
            // Upload to generic media endpoint
            final uploadResponse = await ApiService.uploadFile(
              '/upload/media',
              file,
              fieldName: 'image',
            );
            if (uploadResponse['success'] == true) {
              final mediaData = uploadResponse['data']?['media'] ?? uploadResponse['data'];
              mediaList.add(ComplaintMedia(
                url: mediaData['url'] ?? uploadResponse['data']?['url'] ?? '',
                publicId: mediaData['publicId']?.toString() ?? uploadResponse['data']?['publicId']?.toString(),
                type: 'image',
              ));
            }
          } catch (e) {
            print('❌ [FLUTTER] Error uploading image: $e');
          }
        }
      }

      final complaintData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'subCategory': _subCategoryController.text.trim(),
        'priority': _selectedPriority,
        'location': {
          'specificLocation': _locationController.text.trim(),
        },
        if (mediaList != null && mediaList.isNotEmpty)
          'media': mediaList.map((m) => m.toJson()).toList(),
      };

      print('📋 [FLUTTER] Complaint Data:');
      print('  - Title: ${complaintData['title']}');
      print('  - Category: ${complaintData['category']}');
      print('  - Priority: ${complaintData['priority']}');
      print('  - Media Count: ${mediaList?.length ?? 0}');

      print('📤 [FLUTTER] Sending complaint creation request...');
      final response = await ApiService.post(ApiConstants.complaints, complaintData);

      print('✅ [FLUTTER] Complaint creation response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (mounted) {
        AppMessageHandler.handleResponse(
          context,
          response,
          onSuccess: () {
            Navigator.pop(context);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSubmitting,
      message: 'Submitting complaint...',
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Raise Complaint'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Complaint Title *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Water leakage in bathroom',
                  helperText: 'Minimum 2 characters, maximum 4 words',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter complaint title';
                  }
                  final trimmed = value.trim();
                  if (trimmed.length < 2) {
                    return 'Title must be at least 2 characters';
                  }
                  final wordCount = _countWords(trimmed);
                  if (wordCount > 4) {
                    return 'Title must not exceed 4 words';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  print('🖱️ [FLUTTER] Category changed to: $value');
                  setState(() => _selectedCategory = value ?? 'Electrical');
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Sub Category',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Ceiling leak, Pipe burst',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority *',
                  border: OutlineInputBorder(),
                ),
                items: _priorities.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                onChanged: (value) {
                  print('🖱️ [FLUTTER] Priority changed to: $value');
                  setState(() => _selectedPriority = value ?? 'Medium');
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Describe the issue in detail...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Specific Location',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Master bedroom, Kitchen sink',
                ),
              ),
              const SizedBox(height: 24),
              
              // Image Upload Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.photo_library, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Attach Photos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedImages.length}/4',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImages.isEmpty)
                      InkWell(
                        onTap: _showImageSourceDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.border,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 32,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add photos (Max 4)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._selectedImages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          if (_selectedImages.length < 4)
                            InkWell(
                              onTap: _showImageSourceDialog,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.border,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 24,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                text: 'Submit Complaint',
                isLoading: _isSubmitting,
                onPressed: _submitComplaint,
                icon: Icons.send,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

