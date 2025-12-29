import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/admin/bulk_resident_management_screen.dart';
import '../screens/admin/complaints_management_screen.dart';
import '../screens/admin/settings_screen.dart';
import '../screens/staff/visitor_checkin_screen.dart';
import '../screens/complaints/complaints_screen.dart';
import '../screens/notices/notices_screen.dart';
import 'dart:convert';

/// Drawer item model
class DrawerItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool isDivider;
  final bool isLogout;

  const DrawerItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.isDivider = false,
    this.isLogout = false,
  });
}

/// Drawer section model
class DrawerSection {
  final String? title;
  final List<DrawerItem> items;

  const DrawerSection({
    this.title,
    required this.items,
  });
}

/// Reusable App Sidebar Widget
/// Provides consistent sidebar/drawer across all screens
class AppSidebar extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final String? subtitle;
  final IconData? headerIcon;
  final List<DrawerSection> sections;
  final VoidCallback? onLogout;
  final Color? headerBackgroundColor;

  const AppSidebar({
    super.key,
    this.userName,
    this.userEmail,
    this.subtitle,
    this.headerIcon,
    required this.sections,
    this.onLogout,
    this.headerBackgroundColor,
  });

  /// Build drawer header with consistent styling
  Widget _buildHeader() {
    final displayName = userName ?? 'User';
    final displayEmail = userEmail;
    final displaySubtitle = subtitle;
    final icon = headerIcon ?? Icons.person;

    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: headerBackgroundColor != null
              ? [
                  headerBackgroundColor!,
                  headerBackgroundColor!.withOpacity(0.8),
                ]
              : [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: headerIcon != null
                  ? Icon(
                      icon,
                      color: AppColors.primary,
                      size: 30,
                    )
                  : Text(
                      displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (displayEmail != null) ...[
            const SizedBox(height: 4),
            Text(
              displayEmail,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
          if (displaySubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              displaySubtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build drawer section with title
  Widget _buildSection(DrawerSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              section.title!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ...section.items.map((item) {
          if (item.isDivider) {
            return const Divider(height: 1);
          }
          if (item.isLogout) {
            return ListTile(
              leading: Icon(item.icon, color: AppColors.error),
              title: Text(
                item.title,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: item.onTap ??
                  () {
                    _handleLogout();
                  },
            );
          }
          return ListTile(
            leading: Icon(item.icon, color: AppColors.primary),
            title: Text(item.title),
            onTap: item.onTap,
          );
        }),
      ],
    );
  }

  /// Handle logout action
  void _handleLogout() async {
    await StorageService.remove(AppConstants.tokenKey);
    await StorageService.remove(AppConstants.userKey);
    ApiService.setToken(null);
    
    // Use the provided onLogout callback or default behavior
    if (onLogout != null) {
      onLogout!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            ...sections.expand((section) => [
                  _buildSection(section),
                  if (section != sections.last) const Divider(height: 1),
                ]),
          ],
        ),
      ),
    );
  }
}

/// Helper class to build sidebar for different user roles
class AppSidebarBuilder {
  /// Build admin sidebar
  static Widget buildAdminSidebar({
    String? buildingName,
    required BuildContext context,
    List<Map<String, dynamic>>? buildings,
    String? selectedBuildingCode,
    Function(String)? onBuildingSelected,
  }) {
    final userJson = StorageService.getString(AppConstants.userKey);
    String? userName;
    String? userEmail;

    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        userName = userData['fullName'] ?? userData['name'] ?? 'Admin';
        userEmail = userData['email'];
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    return AppSidebar(
      userName: userName ?? 'Admin',
      userEmail: userEmail,
      subtitle: buildingName,
      headerIcon: Icons.admin_panel_settings,
      sections: [
        DrawerSection(
          title: 'Management',
          items: [
            DrawerItem(
              icon: Icons.people,
              title: 'Resident Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BulkResidentManagementScreen(),
                  ),
                );
              },
            ),
            DrawerItem(
              icon: Icons.description,
              title: 'Complaints',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComplaintsManagementScreen(),
                  ),
                );
              },
            ),
            DrawerItem(
              icon: Icons.bar_chart,
              title: 'Reports',
              onTap: () {
                Navigator.pop(context);
                AppMessageHandler.showInfo(context, 'Reports coming soon');
              },
            ),
            DrawerItem(
              icon: Icons.apartment,
              title: 'Buildings',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to buildings management
                AppMessageHandler.showInfo(context, 'Buildings management coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          title: 'Settings',
          items: [
            DrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            DrawerItem(
              icon: Icons.security,
              title: 'Permissions',
              onTap: () {
                Navigator.pop(context);
                AppMessageHandler.showInfo(context, 'Permissions coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          title: 'Support',
          items: [
            DrawerItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                Navigator.pop(context);
                AppMessageHandler.showInfo(context, 'Help & Support coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          items: [
            DrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              isLogout: true,
              onTap: () async {
                Navigator.pop(context);
                await StorageService.remove(AppConstants.tokenKey);
                await StorageService.remove(AppConstants.userKey);
                ApiService.setToken(null);
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ],
      onLogout: () {
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const RoleSelectionScreen(),
            ),
            (route) => false,
          );
        }
      },
    );
  }

  /// Build staff sidebar
  static Widget buildStaffSidebar({
    required BuildContext context,
  }) {
    final userJson = StorageService.getString(AppConstants.userKey);
    String? userName;
    String? userEmail;

    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        userName = userData['fullName'] ?? userData['name'] ?? 'Staff';
        userEmail = userData['email'];
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    return AppSidebar(
      userName: userName ?? 'Staff',
      userEmail: userEmail,
      headerIcon: Icons.badge,
      sections: [
        DrawerSection(
          title: 'Tasks',
          items: [
            DrawerItem(
              icon: Icons.assignment,
              title: 'Assigned Complaints',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to assigned complaints
                AppMessageHandler.showInfo(context, 'Assigned complaints coming soon');
              },
            ),
            DrawerItem(
              icon: Icons.qr_code_scanner,
              title: 'Visitor Check-In',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VisitorCheckInScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        DrawerSection(
          title: 'Settings',
          items: [
            DrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to settings
                AppMessageHandler.showInfo(context, 'Settings coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          title: 'Support',
          items: [
            DrawerItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                Navigator.pop(context);
                AppMessageHandler.showInfo(context, 'Help & Support coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          items: [
            DrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              isLogout: true,
              onTap: () async {
                Navigator.pop(context);
                await StorageService.remove(AppConstants.tokenKey);
                await StorageService.remove(AppConstants.userKey);
                ApiService.setToken(null);
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Build resident sidebar
  static Widget buildResidentSidebar({
    required BuildContext context,
  }) {
    final userJson = StorageService.getString(AppConstants.userKey);
    String? userName;
    String? userEmail;

    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        userName = userData['fullName'] ?? userData['name'] ?? 'Resident';
        userEmail = userData['email'];
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    return AppSidebar(
      userName: userName ?? 'Resident',
      userEmail: userEmail,
      headerIcon: Icons.home,
      sections: [
        DrawerSection(
          items: [
            DrawerItem(
              icon: Icons.description,
              title: 'Complaints',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComplaintsScreen(),
                  ),
                );
              },
            ),
            DrawerItem(
              icon: Icons.notifications,
              title: 'Notices',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NoticesScreen(),
                  ),
                );
              },
            ),
            DrawerItem(
              icon: Icons.history,
              title: 'History',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to history
                AppMessageHandler.showInfo(context, 'History coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          title: 'Settings',
          items: [
            DrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to settings
                AppMessageHandler.showInfo(context, 'Settings coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          title: 'Support',
          items: [
            DrawerItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to help
                AppMessageHandler.showInfo(context, 'Help & Support coming soon');
              },
            ),
          ],
        ),
        DrawerSection(
          items: [
            DrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              isLogout: true,
              onTap: () async {
                Navigator.pop(context);
                await StorageService.remove(AppConstants.tokenKey);
                await StorageService.remove(AppConstants.userKey);
                ApiService.setToken(null);
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

