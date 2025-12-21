import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'resident_profile_screen.dart';
import 'admin_profile_screen.dart';
import 'staff_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get user from AuthProvider
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    
    // If no user, try to load from storage
    if (user == null) {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        try {
          final userData = UserData.fromJson(jsonDecode(userJson));
          return _buildProfileByRole(userData.role);
        } catch (e) {
          print('❌ [FLUTTER] Error parsing user data: $e');
        }
      }
      // Default to resident if no user data
      return const ResidentProfileScreen();
    }
    
    // Route to appropriate profile screen based on role
    return _buildProfileByRole(user.role);
  }
  
  Widget _buildProfileByRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const AdminProfileScreen();
      case 'staff':
        return const StaffProfileScreen();
      case 'resident':
      default:
        return const ResidentProfileScreen();
    }
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

