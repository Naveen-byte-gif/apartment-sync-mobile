import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  UserData? _user;
  Map<String, dynamic>? _staffData;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for staff profile');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);
          
          socketService.on('profile_updated', (data) {
            print('📡 [FLUTTER] Profile updated event received');
            _loadData();
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadData() async {
    print('🖱️ [FLUTTER] Loading staff profile data...');
    setState(() => _isLoading = true);
    
    try {
      // Load user data from storage
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        setState(() {
          _user = UserData.fromJson(jsonDecode(userJson));
        });
      }

      // Load staff dashboard data
      try {
        final dashboardResponse = await ApiService.get('/users/dashboard');
        if (dashboardResponse['success'] == true) {
          setState(() {
            _staffData = dashboardResponse['data']?['dashboard'];
          });
        }
      } catch (e) {
        print('⚠️ [FLUTTER] Could not load staff dashboard: $e');
      }

      // Load latest user profile from API
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
      print('❌ [FLUTTER] Error loading staff profile: $e');
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
        title: const Text('Staff Profile'),
        backgroundColor: AppColors.warning,
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
                    // Staff Information
                    _buildStaffInfo(),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                    color: AppColors.warning,
                    width: 3,
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
                              color: AppColors.warning.withOpacity(0.2),
                              child: Center(
                                child: Text(
                                  _user?.fullName[0].toUpperCase() ?? 'S',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.warning.withOpacity(0.2),
                          child: Center(
                            child: Text(
                              _user?.fullName[0].toUpperCase() ?? 'S',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                  _user?.fullName ?? 'Staff',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (_user?.email != null)
                  Text(
                    _user!.email!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'STAFF',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_user?.phoneNumber != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _user!.phoneNumber,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                if (_user?.apartmentCode != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _user!.apartmentCode!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _InfoItem(
            label: 'Role',
            value: 'Staff Member',
            icon: Icons.work,
          ),
          const SizedBox(height: 12),
          _InfoItem(
            label: 'Status',
            value: _user?.status == 'active' ? 'Active' : 'Inactive',
            icon: Icons.verified_user,
          ),
          if (_staffData != null) ...[
            const SizedBox(height: 12),
            _InfoItem(
              label: 'Active Tasks',
              value: '${_staffData!['activeComplaints'] ?? 0}',
              icon: Icons.assignment,
            ),
          ],
          if (_user?.apartmentCode != null) ...[
            const SizedBox(height: 12),
            _InfoItem(
              label: 'Building',
              value: _user!.apartmentCode!,
              icon: Icons.business,
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
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
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

