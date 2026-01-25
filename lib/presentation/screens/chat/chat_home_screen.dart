import '../../../core/imports/app_imports.dart';
import '../../widgets/chat_tab_bar.dart';
import 'community_chat_screen.dart';
import 'p2p_chat_list_screen.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';

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
  String? _selectedBuildingCode;
  List<Map<String, dynamic>> _allBuildings = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // All users get 2 tabs (Community and My Chats) - complaints removed
    _tabController = TabController(length: 2, vsync: this);
    _setupSocketListeners();
    _checkUserRole();
    _loadBuildingsIfAdmin();

    // Reset unread counts when tab changes
    _tabController.addListener(_onTabChanged);
  }

  void _checkUserRole() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final user = UserData.fromJson(jsonDecode(userJson));
        setState(() {
          _isAdmin = user.role == 'admin';
        });
      } catch (e) {
        print('❌ [FLUTTER] Error parsing user data: $e');
      }
    }
  }

  Future<void> _loadBuildingsIfAdmin() async {
    if (!_isAdmin) return;
    
    try {
      final response = await ApiService.get(ApiConstants.adminBuildings);
      if (response['success'] == true) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );

          // Get stored building code or use first building
          if (_allBuildings.isNotEmpty) {
            final storedCode = StorageService.getString(
              AppConstants.selectedBuildingKey,
            );

            final isValidCode = storedCode != null &&
                _allBuildings.any((b) => b['code'] == storedCode);

            if (isValidCode) {
              _selectedBuildingCode = storedCode;
            } else {
              _selectedBuildingCode = _allBuildings.first['code'];
              StorageService.setString(
                AppConstants.selectedBuildingKey,
                _selectedBuildingCode!,
              );
            }
          }
        });
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Reset unread count for the selected tab
      setState(() {
        // All users: 0 = Community, 1 = My Chats
        switch (_tabController.index) {
          case 0:
            _communityUnreadCount = 0;
            break;
          case 1:
            _myChatsUnreadCount = 0;
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
          // Building Selector for Admin
          if (_isAdmin && _allBuildings.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedBuildingCode,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _allBuildings.map((building) {
                        return DropdownMenuItem<String>(
                          value: building['code'],
                          child: Text(
                            building['name'] ?? building['code'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedBuildingCode = newValue;
                          });
                          StorageService.setString(
                            AppConstants.selectedBuildingKey,
                            newValue,
                          );
                          // Reload chat with new building
                          // The CommunityChatScreen will pick up the change via key
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Custom Professional Tab Bar (without AppBar)
          ChatTabBar(
            controller: _tabController,
            communityUnreadCount: _communityUnreadCount,
            myChatsUnreadCount: _myChatsUnreadCount,
          ),

          // Tab Content - Only Community and My Chats (Complaints removed)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CommunityChatScreen(
                  key: ValueKey(_selectedBuildingCode), // Force rebuild when building changes
                  buildingCode: _selectedBuildingCode,
                  isAdmin: _isAdmin,
                ),
                P2PChatListScreen(
                  key: ValueKey(_selectedBuildingCode), // Force rebuild when building changes
                  buildingCode: _selectedBuildingCode,
                  isAdmin: _isAdmin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
