import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppBarType {
  dashboard,
  users,
  complaints,
  news,
  profile,
  home,
}

class ContextualAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppBarType type;
  final String? title;
  final String? subtitle;
  final List<Widget>? customActions;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onFilter;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;
  final Widget? leading;

  const ContextualAppBar({
    super.key,
    required this.type,
    this.title,
    this.subtitle,
    this.customActions,
    this.onSearch,
    this.onNotifications,
    this.onFilter,
    this.onAdd,
    this.onEdit,
    this.onRefresh,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      leading: leading,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: leading != null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: _buildActions(context),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (customActions != null) {
      return customActions!;
    }

    final actions = <Widget>[];

    switch (type) {
      case AppBarType.home:
        if (onSearch != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: onSearch,
              tooltip: 'Search',
            ),
          );
        }
        if (onNotifications != null) {
          actions.add(
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: onNotifications,
                  tooltip: 'Notifications',
                ),
                // Badge can be added here
              ],
            ),
          );
        }
        break;

      case AppBarType.complaints:
        if (onFilter != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: onFilter,
              tooltip: 'Filters',
            ),
          );
        }
        if (onAdd != null) {
          actions.add(
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          );
        }
        if (onRefresh != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: 'Refresh',
            ),
          );
        }
        break;

      case AppBarType.profile:
        if (onEdit != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit Profile',
            ),
          );
        }
        break;

      case AppBarType.dashboard:
        // Dashboard specific actions can be added here
        if (onRefresh != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: 'Refresh',
            ),
          );
        }
        break;

      case AppBarType.users:
        if (onAdd != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: onAdd,
              tooltip: 'Add User',
            ),
          );
        }
        if (onSearch != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: onSearch,
              tooltip: 'Search',
            ),
          );
        }
        break;

      case AppBarType.news:
        if (onSearch != null) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: onSearch,
              tooltip: 'Search',
            ),
          );
        }
        break;

      default:
        break;
    }

    return actions;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

