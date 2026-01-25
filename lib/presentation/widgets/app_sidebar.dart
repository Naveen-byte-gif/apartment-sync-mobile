import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/admin/bulk_resident_management_screen.dart';
import '../screens/admin/complaints_management_screen.dart';
import '../screens/admin/settings_screen.dart';
import '../screens/complaints/complaints_screen.dart';
import '../screens/notices/notices_screen.dart';
import '../screens/visitors/visitor_dashboard_screen.dart';
import '../screens/visitors/visitors_log_screen.dart';
import '../screens/admin/visitor_management_screen.dart';
import '../screens/staff/users_management_screen.dart';
import '../screens/staff/create_user_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

/// Drawer item model
class DrawerItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDivider;
  final bool isLogout;
  final bool isSelected;

  const DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDivider = false,
    this.isLogout = false,
    this.isSelected = false,
  });
}

/// Drawer section model
class DrawerSection {
  final String? title;
  final List<DrawerItem> items;

  const DrawerSection({this.title, required this.items});
}

/// Reusable App Sidebar Widget
/// Provides consistent sidebar/drawer across all screens
class AppSidebar extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final String? subtitle;
  final IconData? headerIcon;
  final String? profilePictureUrl;
  final List<DrawerSection> sections;
  final VoidCallback? onLogout;
  final Color? headerBackgroundColor;
  final Widget? buildingSelector;

  const AppSidebar({
    super.key,
    this.userName,
    this.userEmail,
    this.subtitle,
    this.headerIcon,
    this.profilePictureUrl,
    required this.sections,
    this.onLogout,
    this.headerBackgroundColor,
    this.buildingSelector,
  });

  /// Build drawer header with consistent styling
  Widget _buildHeader() {
    final displayName = userName ?? 'User';
    final displayEmail = userEmail;
    final displaySubtitle = subtitle;
    final icon = headerIcon ?? Icons.person;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: headerBackgroundColor != null
              ? [
                  headerBackgroundColor!,
                  headerBackgroundColor!.withOpacity(0.8),
                ]
              : [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with profile picture or icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child:
                      profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profilePictureUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: headerIcon != null
                                ? Icon(icon, color: AppColors.primary, size: 28)
                                : Text(
                                    displayName.isNotEmpty
                                        ? displayName
                                              .substring(0, 1)
                                              .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: headerIcon != null
                                ? Icon(icon, color: AppColors.primary, size: 28)
                                : Text(
                                    displayName.isNotEmpty
                                        ? displayName
                                              .substring(0, 1)
                                              .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        )
                      : Center(
                          child: headerIcon != null
                              ? Icon(icon, color: AppColors.primary, size: 28)
                              : Text(
                                  displayName.isNotEmpty
                                      ? displayName
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              // Name with overflow protection
              Flexible(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Email with overflow protection
              if (displayEmail != null) ...[
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    displayEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              // Subtitle with overflow protection
              if (displaySubtitle != null) ...[
                const SizedBox(height: 3),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displaySubtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
              onTap:
                  item.onTap ??
                  () {
                    _handleLogout();
                  },
            );
          }
          return ListTile(
            leading: Icon(
              item.icon,
              color: item.isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: item.isSelected ? FontWeight.bold : FontWeight.normal,
                color: item.isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            subtitle: item.subtitle != null
                ? Text(
                    item.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
            selected: item.isSelected,
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
            if (buildingSelector != null) ...[
              buildingSelector!,
              const Divider(height: 1),
            ],
            ...sections.expand(
              (section) => [
                _buildSection(section),
                if (section != sections.last) const Divider(height: 1),
              ],
            ),
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
    String? profilePictureUrl;

    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        userName = userData['fullName'] ?? userData['name'] ?? 'Admin';
        userEmail = userData['email'];
        // Handle profile picture - can be string or object with url
        if (userData['profilePicture'] != null) {
          if (userData['profilePicture'] is String) {
            profilePictureUrl = userData['profilePicture'];
          } else if (userData['profilePicture'] is Map) {
            profilePictureUrl = userData['profilePicture']['url'];
          }
        }
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    // Build building selector widget
    Widget? buildingSelectorWidget;
    if (buildings != null && buildings.isNotEmpty) {
      // Ensure selectedBuildingCode is valid
      final validSelectedCode =
          selectedBuildingCode != null &&
              buildings.any((b) => b['code'] == selectedBuildingCode)
          ? selectedBuildingCode
          : buildings.first['code'] as String?;

      buildingSelectorWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.apartment,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Building (${buildings.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: validSelectedCode,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.primary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  items: buildings.map((building) {
                    final code = building['code'] as String? ?? '';
                    final name = building['name'] as String? ?? 'Unknown';
                    final isSelected = code == validSelectedCode;
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newCode) {
                    if (newCode != null && onBuildingSelected != null) {
                      Navigator.pop(context); // Close drawer
                      onBuildingSelected(newCode);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppSidebar(
      userName: userName ?? 'Admin',
      userEmail: userEmail,
      subtitle: buildingName,
      headerIcon: Icons.admin_panel_settings,
      profilePictureUrl: profilePictureUrl,
      buildingSelector: buildingSelectorWidget,
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
              icon: Icons.person_add,
              title: 'Visitor Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VisitorDashboardScreen(),
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
                AppMessageHandler.showInfo(
                  context,
                  'Buildings management coming soon',
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                AppMessageHandler.showInfo(
                  context,
                  'Help & Support coming soon',
                );
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
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            (route) => false,
          );
        }
      },
    );
  }

  /// Build staff sidebar with building selection and permissions
  static Widget buildStaffSidebar({
    required BuildContext context,
    String? buildingName,
    List<Map<String, dynamic>> buildings = const [],
    String? selectedBuildingCode,
    Function(String?)? onBuildingSelected,
    Map<String, dynamic>? permissions,
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

    final canManageVisitors = permissions?['canManageVisitors'] == true;
    final canManageComplaints = permissions?['canManageComplaints'] == true;
    final canManageAccess = permissions?['canManageAccess'] == true;
    final canManageMaintenance = permissions?['canManageMaintenance'] == true;

    return AppSidebar(
      userName: userName ?? 'Staff',
      userEmail: userEmail,
      headerIcon: Icons.badge,
      sections: [
        // Building Selection Section
        if (buildings.isNotEmpty)
          DrawerSection(
            title: 'Buildings',
            items: buildings.map((building) {
              final code = building['code'] ?? '';
              final name = building['name'] ?? code;
              final isSelected = code == selectedBuildingCode;
              return DrawerItem(
                icon: isSelected ? Icons.check_circle : Icons.business,
                title: name,
                subtitle: 'Code: $code',
                isSelected: isSelected,
                onTap: () {
                  Navigator.pop(context);
                  if (onBuildingSelected != null) {
                    onBuildingSelected(code);
                  }
                },
              );
            }).toList(),
          ),
        // Management Section (Permission-based)
        if (canManageAccess || canManageComplaints || canManageVisitors)
          DrawerSection(
            title: 'Management',
            items: [
              if (canManageAccess)
                DrawerItem(
                  icon: Icons.people,
                  title: 'Users Management',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StaffUsersManagementScreen(),
                      ),
                    );
                  },
                ),
              if (canManageComplaints)
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
              if (canManageVisitors)
                DrawerItem(
                  icon: Icons.people_outline,
                  title: 'Visitor Logs',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisitorDashboardScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        // Tasks Section
        DrawerSection(
          title: 'Tasks',
          items: [
            if (canManageAccess)
              DrawerItem(
                icon: Icons.person_add,
                title: 'Create Resident',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffCreateUserScreen(),
                    ),
                  );
                },
              ),
            if (canManageComplaints)
              DrawerItem(
                icon: Icons.assignment,
                title: 'My Assignments',
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
            if (canManageVisitors)
              DrawerItem(
                icon: Icons.qr_code_scanner,
                title: 'Visitor Check-In',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisitorDashboardScreen(),
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
                AppMessageHandler.showInfo(
                  context,
                  'Help & Support coming soon',
                );
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
  static Widget buildResidentSidebar({required BuildContext context}) {
    final userJson = StorageService.getString(AppConstants.userKey);
    String? userName;
    String? userEmail;
    String? profilePictureUrl;

    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        userName = userData['fullName'] ?? userData['name'] ?? 'Resident';
        userEmail = userData['email'];
        // Handle profile picture
        if (userData['profilePicture'] != null) {
          if (userData['profilePicture'] is String) {
            profilePictureUrl = userData['profilePicture'];
          } else if (userData['profilePicture'] is Map) {
            profilePictureUrl = userData['profilePicture']['url'];
          }
        }
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }

    return AppSidebar(
      userName: userName ?? 'Resident',
      userEmail: userEmail,
      headerIcon: Icons.home,
      profilePictureUrl: profilePictureUrl,
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
                  MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
                );
              },
            ),
            DrawerItem(
              icon: Icons.people,
              title: 'My Visitors',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisitorsLogScreen()),
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
                  MaterialPageRoute(builder: (_) => const NoticesScreen()),
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
                AppMessageHandler.showInfo(
                  context,
                  'Help & Support coming soon',
                );
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
