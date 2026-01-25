import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import '../auth/role_selection_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ResidentProfileScreen extends StatefulWidget {
  final bool showAppBar;
  
  const ResidentProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  UserData? _user;
  Map<String, dynamic>? _buildingData;
  Map<String, dynamic>? _flatData;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for profile');
    final socketService = SocketService();
    final userId = _user?.id ?? '';
    if (userId.isNotEmpty) {
      socketService.connect(userId);
      
      socketService.on('profile_updated', (data) {
        print('📡 [FLUTTER] Profile updated event received');
        _loadData(); // Refresh profile data
      });
    }
  }

  Future<void> _loadData() async {
    print('🖱️ [FLUTTER] Loading profile data...');
    setState(() => _isLoading = true);
    
    try {
      // Load user data
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        setState(() {
          _user = UserData.fromJson(jsonDecode(userJson));
        });
      }

      // Load building and flat details
      final buildingResponse = await ApiService.get(ApiConstants.buildingDetails);
      if (buildingResponse['success'] == true) {
        setState(() {
          _buildingData = buildingResponse['data']?['building'];
          _flatData = buildingResponse['data']?['flat'];
        });
      }

      // Load user profile from API to get latest data
      final profileResponse = await ApiService.get('/auth/me');
      if (profileResponse['success'] == true && profileResponse['data']?['user'] != null) {
        setState(() {
          _user = UserData.fromJson(profileResponse['data']['user']);
        });
        // Update storage
        await StorageService.setString(
          AppConstants.userKey,
          jsonEncode(_user!.toJson()),
        );
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            backgroundColor: AppColors.background,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Card
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  // Flat Details
                  _buildFlatDetails(),
                  const SizedBox(height: 20),
                  // Account Section
                  _buildAccountSection(),
                  const SizedBox(height: 20),
                  // Preferences Section
                  _buildPreferencesSection(),
                  const SizedBox(height: 20),
                  // Support Section
                  _buildSupportSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: content,
      );
    }
    
    // When used in tabs, wrap in container with background color
    return Container(
      color: AppColors.background,
      child: content,
    );
  }

  Widget _buildProfileCard() {
    final profilePictureUrl = _user?.profilePicture;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                      ? Image.network(
                          profilePictureUrl,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: Center(
                                child: Text(
                                  _user?.fullName[0].toUpperCase() ?? 'R',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: Center(
                            child: Text(
                              _user?.fullName[0].toUpperCase() ?? 'R',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _user?.fullName ?? 'Resident',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apartment,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _user?.flatNumber != null && _user?.wing != null
                    ? '${_user!.wing}-${_user!.flatNumber}'
                    : _user?.flatNumber ?? 'No flat assigned',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_user?.email != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Text(
                  _user!.email!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _user?.role == 'admin'
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _user?.role?.toUpperCase() ?? 'RESIDENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: _user?.role == 'admin'
                    ? AppColors.error
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.apartment,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Flat Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Flat Number',
                        value: _flatData?['flatNumber'] ?? _user?.flatNumber ?? 'N/A',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Floor',
                        value: _flatData != null
                            ? '${_flatData!['floorNumber']}'
                            : _user?.floorNumber?.toString() ?? 'N/A',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: AppColors.border,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Wing',
                        value: _user?.wing ?? 'N/A',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Type',
                        value: _flatData?['flatType'] ?? _user?.flatType ?? 'N/A',
                      ),
                    ),
                  ],
                ),
                if (_flatData?['squareFeet'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 16),
                  _DetailItem(
                    label: 'Area',
                    value: '${_flatData!['squareFeet']} sq.ft',
                  ),
                ],
                if (_user?.emergencyContact != null && _user!.emergencyContact!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 16),
                  _DetailItem(
                    label: 'Emergency Contact',
                    value: _user!.emergencyContact!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'ACCOUNT'),
        _MenuItem(
          icon: Icons.person,
          title: 'Edit Profile',
          onTap: () {
            print('🖱️ [FLUTTER] Edit profile menu tapped');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(user: _user),
              ),
            ).then((_) => _loadData());
          },
        ),
        _MenuItem(
          icon: Icons.lock_outline,
          title: 'Change Password',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'PREFERENCES'),
        _SwitchMenuItem(
          icon: Icons.notifications,
          title: 'Notifications',
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() => _notificationsEnabled = value);
            print('🖱️ [FLUTTER] Notifications toggled: $value');
            // TODO: Update notification preferences via API
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'SUPPORT'),
        _MenuItem(
          icon: Icons.help,
          title: 'Help & Support',
          onTap: () {
            print('🖱️ [FLUTTER] Help tapped');
          },
        ),
        _MenuItem(
          icon: Icons.logout,
          title: 'Logout',
          onTap: _handleLogout,
          textColor: Colors.red,
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      print('🖱️ [FLUTTER] Logging out...');
      await StorageService.remove(AppConstants.tokenKey);
      await StorageService.remove(AppConstants.userKey);
      ApiService.setToken(null);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (textColor ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: textColor ?? AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: textColor ?? AppColors.textLight,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchMenuItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }
}




