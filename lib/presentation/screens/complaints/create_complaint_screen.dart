import '../../../core/imports/app_imports.dart';

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
  
  String _selectedCategory = 'Electrical';
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;

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

  Future<void> _submitComplaint() async {
    print('🖱️ [FLUTTER] Submit complaint button clicked');
    if (!_formKey.currentState!.validate()) {
      print('❌ [FLUTTER] Form validation failed');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final complaintData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'subCategory': _subCategoryController.text.trim(),
        'priority': _selectedPriority,
        'location': {
          'specificLocation': _locationController.text.trim(),
        }
      };

      print('📋 [FLUTTER] Complaint Data:');
      print('  - Title: ${complaintData['title']}');
      print('  - Category: ${complaintData['category']}');
      print('  - Priority: ${complaintData['priority']}');

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
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter complaint title';
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

