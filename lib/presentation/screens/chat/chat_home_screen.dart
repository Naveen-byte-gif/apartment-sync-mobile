import '../../../core/imports/app_imports.dart';
import '../../widgets/chat_tab_bar.dart';
import 'community_chat_screen.dart';
import 'p2p_chat_list_screen.dart';
import 'complaint_chat_list_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _communityUnreadCount = 0;
  int _myChatsUnreadCount = 0;
  int _complaintsUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupSocketListeners();

    // Reset unread counts when tab changes
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Reset unread count for the selected tab
      setState(() {
        switch (_tabController.index) {
          case 0:
            _communityUnreadCount = 0;
            break;
          case 1:
            _myChatsUnreadCount = 0;
            break;
          case 2:
            _complaintsUnreadCount = 0;
            break;
        }
      });
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // Listen for new community messages
    socketService.on('new_community_message', (data) {
      if (mounted) {
        setState(() {
          if (_tabController.index != 0) {
            _communityUnreadCount++;
          }
        });
      }
    });

    // Listen for P2P messages
    socketService.on('p2p_message_received', (data) {
      if (mounted) {
        setState(() {
          if (_tabController.index != 1) {
            _myChatsUnreadCount++;
          }
        });
      }
    });

    // Listen for complaint messages
    socketService.on('complaint_message', (data) {
      if (mounted) {
        setState(() {
          if (_tabController.index != 2) {
            _complaintsUnreadCount++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Custom Professional Tab Bar (without AppBar)
          ChatTabBar(
            controller: _tabController,
            communityUnreadCount: _communityUnreadCount,
            myChatsUnreadCount: _myChatsUnreadCount,
            complaintsUnreadCount: _complaintsUnreadCount,
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                CommunityChatScreen(),
                P2PChatListScreen(),
                ComplaintChatListScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
