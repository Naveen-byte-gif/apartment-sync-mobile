import '../../core/imports/app_imports.dart';

/// Empty State Widget for Chat Screens
/// 
/// This widget provides user-friendly empty states for various chat scenarios:
/// 1. Community Chat - When no messages exist yet
/// 2. P2P Chats - When user has no conversations
/// 3. Complaint Chats - When no complaints exist
/// 
/// Guidelines for proper usage:
/// - Always provide meaningful title and description
/// - Use appropriate icon for context (community, p2p, complaints)
/// - Include helpful tips when relevant
/// - Maintain consistent design language across all chat screens
/// - Keep messages encouraging and actionable
/// 
/// Best Practices:
/// - Use clear, concise messages
/// - Provide visual hierarchy with icons and spacing
/// - Add helpful tips for new users
/// - Make empty states actionable when possible
class ChatEmptyStateWidget extends StatelessWidget {
  /// Type of chat screen (community, p2p, complaints)
  final ChatEmptyStateType type;
  
  /// Optional custom title (uses default if null)
  final String? customTitle;
  
  /// Optional custom description (uses default if null)
  final String? customDescription;
  
  /// Optional action callback (e.g., "Start Chatting")
  final VoidCallback? onAction;
  
  /// Optional action button text
  final String? actionText;

  const ChatEmptyStateWidget({
    super.key,
    required this.type,
    this.customTitle,
    this.customDescription,
    this.onAction,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration Icon
            _buildIcon(),
            const SizedBox(height: 32),
            
            // Title
            Text(
              customTitle ?? _getDefaultTitle(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Description
            Text(
              customDescription ?? _getDefaultDescription(),
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Action Button (if provided)
            if (onAction != null && actionText != null)
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(_getActionIcon(), size: 24),
                label: Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Helpful Tips
            _buildTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor;
    Color backgroundColor;

    switch (type) {
      case ChatEmptyStateType.community:
        iconData = Icons.people_outline_rounded;
        iconColor = AppColors.primary;
        backgroundColor = AppColors.primary.withOpacity(0.1);
        break;
      case ChatEmptyStateType.p2p:
        iconData = Icons.chat_bubble_outline_rounded;
        iconColor = Colors.blue;
        backgroundColor = Colors.blue.withOpacity(0.1);
        break;
      case ChatEmptyStateType.complaints:
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 80,
        color: iconColor,
      ),
    );
  }

  String _getDefaultTitle() {
    switch (type) {
      case ChatEmptyStateType.community:
        return 'No Messages Yet';
      case ChatEmptyStateType.p2p:
        return 'No Conversations';
      case ChatEmptyStateType.complaints:
        return 'No Complaints Yet';
    }
  }

  String _getDefaultDescription() {
    switch (type) {
      case ChatEmptyStateType.community:
        return 'Start the conversation! Share updates, ask questions, or connect with your community.';
      case ChatEmptyStateType.p2p:
        return 'Start a conversation with residents or staff members. Your chats will appear here.';
      case ChatEmptyStateType.complaints:
        return 'You haven\'t submitted any complaints yet. Use the complaints section to report issues or request assistance.';
    }
  }

  IconData _getActionIcon() {
    switch (type) {
      case ChatEmptyStateType.community:
        return Icons.send_rounded;
      case ChatEmptyStateType.p2p:
        return Icons.chat_rounded;
      case ChatEmptyStateType.complaints:
        return Icons.add_circle_outline;
    }
  }

  Widget _buildTips() {
    List<String> tips = _getTips();
    
    if (tips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => _buildTipItem(tip)),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getTips() {
    switch (type) {
      case ChatEmptyStateType.community:
        return [
          'Be respectful and considerate in your messages',
          'Share helpful information with your neighbors',
          'Use community chat for general discussions',
        ];
      case ChatEmptyStateType.p2p:
        return [
          'Tap on a contact to start a private conversation',
          'Use private chats for personal discussions',
          'Your conversation history is saved automatically',
        ];
      case ChatEmptyStateType.complaints:
        return [
          'Submit complaints for any maintenance issues',
          'Track your complaint status here',
          'Staff will respond to your complaints',
        ];
    }
  }
}

/// Types of empty states for chat screens
enum ChatEmptyStateType {
  /// Community chat empty state
  community,
  
  /// P2P (peer-to-peer) chat empty state
  p2p,
  
  /// Complaint chat empty state
  complaints,
}

