import 'package:apartment_aync_mobile/presentation/screens/admin/payment_verification_screen.dart';
import 'package:apartment_aync_mobile/presentation/screens/admin/upi_config_screen.dart';
import 'package:apartment_aync_mobile/presentation/screens/admin/invoice_management_screen.dart';

import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import '../auth/role_selection_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  UserData? _user;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for admin profile');
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
    print('🖱️ [FLUTTER] Loading admin profile data...');
    setState(() => _isLoading = true);

    try {
      // Load user data from storage
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        setState(() {
          _user = UserData.fromJson(jsonDecode(userJson));
        });
      }

      // Load latest user profile from API
      final profileResponse = await ApiService.get('/auth/me');
      if (profileResponse['success'] == true &&
          profileResponse['data']?['user'] != null) {
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
      print('❌ [FLUTTER] Error loading admin profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Admin Profile'),
      //   backgroundColor: AppColors.primary,
      // ),
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
                    // Admin Information
                    _buildAdminInfo(),
                    const SizedBox(height: 20),
                    // Account Section
                    _buildAccountSection(),
                    const SizedBox(height: 20),
                    // Payment Management Section
                    _buildPaymentSection(),
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
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                  ? Image.network(
                      profilePictureUrl,
                      fit: BoxFit.cover,
                      width: 70,
                      height: 70,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            _user?.fullName[0].toUpperCase() ?? 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        _user?.fullName[0].toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.fullName ?? 'Admin',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (_user?.email != null)
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _user!.email!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ADMINISTRATOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: _user),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Admin Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoItem(
            label: 'Role',
            value: 'Administrator',
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 16),
          _InfoItem(
            label: 'Status',
            value: _user?.status == 'active' ? 'Active' : 'Inactive',
            icon: _user?.status == 'active'
                ? Icons.verified_user
                : Icons.pending_outlined,
            statusColor: _user?.status == 'active'
                ? AppColors.success
                : AppColors.warning,
          ),
          if (_user?.phoneNumber != null) ...[
            const SizedBox(height: 16),
            _InfoItem(
              label: 'Phone',
              value: _user!.phoneNumber,
              icon: Icons.phone_outlined,
            ),
          ],
          if (_user?.emergencyContact != null &&
              _user!.emergencyContact!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoItem(
              label: 'Emergency Contact',
              value: _user!.emergencyContact!,
              icon: Icons.emergency_outlined,
              statusColor: AppColors.error,
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
          icon: Icons.lock_outline,
          title: 'Change Password',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'PAYMENT MANAGEMENT'),
        _MenuItem(
          icon: Icons.receipt_long,
          title: 'Invoice Management',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InvoiceManagementScreen(),
              ),
            );
          },
        ),
        _MenuItem(
          icon: Icons.account_balance_wallet,
          title: 'UPI Configuration',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpiConfigScreen()),
            );
          },
        ),
        _MenuItem(
          icon: Icons.verified_user,
          title: 'Payment Verification',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentVerificationScreen(),
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

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? statusColor;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (statusColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: statusColor ?? AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: statusColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? Colors.grey.shade700),
        title: Text(title, style: TextStyle(color: textColor)),
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
