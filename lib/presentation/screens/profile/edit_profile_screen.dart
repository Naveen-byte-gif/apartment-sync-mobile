import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class EditProfileScreen extends StatefulWidget {
  final UserData? user;

  const EditProfileScreen({super.key, this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _hasChanges = false;
  File? _selectedImage;
  String? _currentProfilePictureUrl;
  
  String? _initialFullName;
  String? _initialEmail;
  String? _initialEmergencyContact;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.user != null) {
      _fullNameController.text = widget.user!.fullName;
      _emailController.text = widget.user!.email ?? '';
      _emergencyContactController.text = widget.user!.emergencyContact ?? '';
      _initialFullName = widget.user!.fullName;
      _initialEmail = widget.user!.email;
      _initialEmergencyContact = widget.user!.emergencyContact;
      
      // Get profile picture URL
      if (widget.user!.profilePicture != null) {
        if (widget.user!.profilePicture is String) {
          _currentProfilePictureUrl = widget.user!.profilePicture as String;
        } else if (widget.user!.profilePicture is Map) {
          _currentProfilePictureUrl = (widget.user!.profilePicture as Map)['url'] as String?;
        }
      }
      
      // Add listeners to detect changes
      _fullNameController.addListener(_checkForChanges);
      _emailController.addListener(_checkForChanges);
      _emergencyContactController.addListener(_checkForChanges);
    }
  }

  void _checkForChanges() {
    final hasChanges = _fullNameController.text != _initialFullName ||
        _emailController.text != (_initialEmail ?? '') ||
        _emergencyContactController.text.trim() != (_initialEmergencyContact ?? '') ||
        _selectedImage != null;
    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  String _getRoleLabel() {
    final role = widget.user?.role?.toUpperCase() ?? 'RESIDENT';
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ADMINISTRATOR';
      case 'staff':
        return 'STAFF';
      case 'resident':
      default:
        return 'RESIDENT';
    }
  }

  Color _getRoleColor() {
    final role = widget.user?.role?.toLowerCase() ?? 'resident';
    switch (role) {
      case 'admin':
        return AppColors.error;
      case 'staff':
        return AppColors.warning;
      case 'resident':
      default:
        return AppColors.primary;
    }
  }

  Future<void> _loadData() async {
    // No need to load building/flat data anymore
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _checkForChanges();
        // Upload will happen when saving profile
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadProfilePicture() async {
    if (_selectedImage == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      // TODO: Replace with generic upload endpoint
      // Upload to generic media endpoint
      final response = await ApiService.uploadFile(
        '/upload/media',
        _selectedImage!,
        fieldName: 'image',
      );

      if (response['success'] == true) {
        final media = response['data']?['media'];
        if (media != null && media['url'] != null) {
          final imageUrl = media['url'] as String;
          setState(() {
            _currentProfilePictureUrl = imageUrl;
          });
          return imageUrl;
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error uploading profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload profile picture first if selected
      String? profilePictureUrl;
      if (_selectedImage != null) {
        profilePictureUrl = await _uploadProfilePicture();
        if (profilePictureUrl == null && _selectedImage != null) {
          // Upload failed, but continue with other updates
          print('⚠️ [FLUTTER] Profile picture upload failed, continuing with other updates');
        }
      }

      final updateData = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim().isEmpty
            ? null
            : _emergencyContactController.text.trim(),
        if (profilePictureUrl != null) 'profilePicture': profilePictureUrl,
      };

      final response = await ApiService.put('/users/profile', updateData);

      if (response['success'] == true) {
        if (response['data']?['user'] != null) {
          final updatedUser = UserData.fromJson(response['data']['user']);
          await StorageService.setString(
            AppConstants.userKey,
            jsonEncode(updatedUser.toJson()),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.border,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtitle
              Text(
                'Keep your details up to date',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Resident Identity Card
              _buildResidentIdentityCard(),
              const SizedBox(height: 24),
              
              // Editable Personal Information Section
              _buildEditableSection(),
              const SizedBox(height: 100), // Space for fixed button
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildResidentIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        )
                      : _currentProfilePictureUrl != null && _currentProfilePictureUrl!.isNotEmpty
                          ? Image.network(
                              _currentProfilePictureUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildAvatarPlaceholder();
                              },
                            )
                          : _buildAvatarPlaceholder(),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickImage,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isUploadingImage ? AppColors.textLight : AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.user?.fullName ?? 'Resident',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          // Show location only for residents
          if (widget.user?.role == 'resident') ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.user?.flatCode ?? 'N/A',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (widget.user?.wing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.user!.wing!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRoleLabel(),
              style: TextStyle(
                color: _getRoleColor(),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          widget.user?.fullName[0].toUpperCase() ?? 'R',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEditableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          icon: Icons.person_outline,
          isRequired: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: TextEditingController(text: widget.user?.phoneNumber ?? ''),
          label: 'Mobile Number',
          icon: Icons.phone_outlined,
          enabled: false,
          helperText: 'Contact admin to change mobile number',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emergencyContactController,
          label: 'Emergency Contact (Optional)',
          icon: Icons.emergency_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? AppColors.border : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(
            color: enabled ? AppColors.textSecondary : AppColors.textLight,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          helperText: helperText,
          helperStyle: TextStyle(
            fontSize: 12,
            color: AppColors.textLight,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
