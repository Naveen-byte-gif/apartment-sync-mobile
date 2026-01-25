import '../../core/imports/app_imports.dart';

/// Professional Custom Tab Bar for Chat Home Screen
/// 
/// This widget provides a modern, professional tab bar design without requiring AppBar.
/// Features:
/// - Clean, modern design with smooth animations
/// - Unread count badges for each tab
/// - Customizable colors and styling
/// - Accessible and user-friendly
/// 
/// Guidelines for proper usage:
/// - Always provide TabController from parent widget
/// - Pass unread counts for badge display
/// - Use consistent colors from AppColors theme
/// - Ensure tabs are accessible (min touch target size)
/// 
/// Best Practices:
/// - Keep tab labels concise (max 2 words)
/// - Update unread counts in real-time
/// - Provide visual feedback on tab selection
/// - Maintain consistent spacing and padding
class ChatTabBar extends StatelessWidget {
  /// TabController to manage tab state
  final TabController controller;
  
  /// Unread count for Community tab
  final int communityUnreadCount;
  
  /// Unread count for My Chats tab
  final int myChatsUnreadCount;

  const ChatTabBar({
    super.key,
    required this.controller,
    this.communityUnreadCount = 0,
    this.myChatsUnreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: TabBar(
          controller: controller,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: [
            _ChatTab(
              icon: Icons.people_rounded,
              label: 'Community',
              unreadCount: communityUnreadCount,
            ),
            _ChatTab(
              icon: Icons.chat_bubble_rounded,
              label: 'My Chats',
              unreadCount: myChatsUnreadCount,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual Tab Widget with Unread Badge
class _ChatTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int unreadCount;

  const _ChatTab({
    required this.icon,
    required this.label,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
          if (unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

