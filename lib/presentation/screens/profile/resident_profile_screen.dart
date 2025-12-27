import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import '../auth/role_selection_screen.dart';
import 'edit_profile_screen.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        actions: [
          TextButton(
            onPressed: () {
              print('🖱️ [FLUTTER] Edit profile button clicked');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: _user),
                ),
              ).then((_) => _loadData());
            },
            child: const Text(
              'Edit',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final profilePictureUrl = _user?.profilePicture;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                      ? Image.network(
                          profilePictureUrl,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primary.withOpacity(0.2),
                              child: Center(
                                child: Text(
                                  _user?.fullName[0].toUpperCase() ?? 'R',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.primary.withOpacity(0.2),
                          child: Center(
                            child: Text(
                              _user?.fullName[0].toUpperCase() ?? 'R',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 32,
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
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.fullName ?? 'Resident',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.flatNumber != null && _user?.wing != null
                      ? '${_user!.flatNumber} • ${_user!.wing}'
                      : _user?.flatNumber ?? 'No flat assigned',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _user?.role == 'admin'
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _user?.role?.toUpperCase() ?? 'RESIDENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _user?.role == 'admin'
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flat Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'Flat Number',
                  value: _flatData?['flatNumber'] ?? _user?.flatNumber ?? 'N/A',
                ),
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
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'Wing',
                  value: _user?.wing ?? 'N/A',
                ),
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
            _DetailItem(
              label: 'Area',
              value: '${_flatData!['squareFeet']} sq.ft',
            ),
          ],
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
          icon: Icons.lock,
          title: 'Change Password',
          onTap: () {
            print('🖱️ [FLUTTER] Change password tapped');
            // TODO: Navigate to change password screen
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? Colors.grey.shade700),
        title: Text(
          title,
          style: TextStyle(color: textColor),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(title),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }
}



