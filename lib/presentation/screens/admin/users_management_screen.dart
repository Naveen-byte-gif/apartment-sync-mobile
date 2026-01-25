import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import '../../widgets/users_empty_state_widget.dart';
import 'create_user_screen.dart';
import 'building_view_3d_screen.dart';
import '../chat/p2p_chat_screen.dart';
import 'complaints_management_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<UserData> _users = [];
  Map<String, List<UserData>> _usersByBuilding = {};
  List<UserData> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'resident';
  String _searchQuery = '';
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;
  Set<String> _expandedBuildings = {};

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _setupSocketListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if building code has changed in storage
    final currentStoredCode = StorageService.getString(
      AppConstants.selectedBuildingKey,
    );
    if (currentStoredCode != _selectedBuildingCode &&
        currentStoredCode != null) {
      // Building code changed, reload data
      setState(() {
        _selectedBuildingCode = currentStoredCode;
      });
      _loadUsers();
    }
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for users');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          // Listen for user creation
          socketService.on('user_created', (data) {
            print('📡 [FLUTTER] User created event received');
            if (mounted) {
              _loadUsers();
              AppMessageHandler.showSuccess(context, 'New user added');
            }
          });

          // Listen for user updates
          socketService.on('user_updated', (data) {
            print('📡 [FLUTTER] User updated event received');
            if (mounted) {
              _loadUsers();   
            }
          });

          // Listen for flat status updates (affects residents)
          socketService.on('flat_status_updated', (data) {
            print('📡 [FLUTTER] Flat status updated event received');
            if (mounted) {
              _loadUsers();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadBuildings() async {
    try {
      final response = await ApiService.get(ApiConstants.adminBuildings);
      if (response['success'] == true) {
        setState(() {
          _allBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );

          // Validate stored building code against fetched buildings
          if (_allBuildings.isNotEmpty) {
            final storedCode = StorageService.getString(
              AppConstants.selectedBuildingKey,
            );

            // Check if stored code exists in the fetched buildings
            final isValidCode =
                storedCode != null &&
                _allBuildings.any((b) => b['code'] == storedCode);

            if (isValidCode) {
              _selectedBuildingCode = storedCode;
            } else {
              // Use first building and update storage
              _selectedBuildingCode = _allBuildings.first['code'];
              StorageService.setString(
                AppConstants.selectedBuildingKey,
                _selectedBuildingCode!,
              );
            }
          }
        });
        _loadUsers();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    print('🖱️ [FLUTTER] Loading users...');
    setState(() => _isLoading = true);
    try {
      // Load all users (not filtered by building) to group by building
      final response = await ApiService.get(ApiConstants.adminUsers);
      print('✅ [FLUTTER] Users response received');

      if (response['success'] == true) {
        final usersList = response['data']?['users'] as List?;
        if (usersList != null) {
          final loadedUsers = usersList
              .map((u) => UserData.fromJson(u))
              .toList();
          setState(() {
            _users = loadedUsers;
            _groupUsersByBuilding();
            _applyFilters();
          });
          print('✅ [FLUTTER] Loaded ${_users.length} users');
        }
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading users: $e');
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _groupUsersByBuilding() {
    _usersByBuilding.clear();
    for (var user in _users) {
      final buildingCode = user.apartmentCode ?? 'Unknown';
      if (!_usersByBuilding.containsKey(buildingCode)) {
        _usersByBuilding[buildingCode] = [];
      }
      _usersByBuilding[buildingCode]!.add(user);
    }
    // Sort buildings by name
    final sortedBuildings = _usersByBuilding.keys.toList()..sort();
    final sortedMap = <String, List<UserData>>{};
    for (var code in sortedBuildings) {
      sortedMap[code] = _usersByBuilding[code]!;
    }
    _usersByBuilding = sortedMap;

    // Auto-expand first building if only one building
    if (_usersByBuilding.length == 1) {
      _expandedBuildings.add(_usersByBuilding.keys.first);
    }
  }

  /// Efficiently filter users for large datasets (500+ users)
  /// Uses optimized string matching with case-insensitive search
  void _applyFilters() {
    setState(() {
      final query = _searchQuery.trim().toLowerCase();
      final isSearchActive = query.isNotEmpty;

      // Filter users
      final filtered = _users.where((user) {
        // Role filter (required - no 'all' option)
        if (user.role != _selectedFilter) {
          return false;
        }

        // Building filter
        if (_selectedBuildingCode != null &&
            user.apartmentCode != _selectedBuildingCode) {
          return false;
        }

        // Search filter (only if search query exists)
        if (isSearchActive) {
          // Optimized search: check most common fields first
          final nameMatch = user.fullName.toLowerCase().contains(query);
          final phoneMatch = user.phoneNumber.contains(query);

          if (nameMatch || phoneMatch) {
            return true;
          }

          // Check optional fields
          final emailMatch = user.email?.toLowerCase().contains(query) ?? false;
          final flatNumberMatch =
              user.flatNumber?.toLowerCase().contains(query) ?? false;
          final flatCodeMatch =
              user.flatCode?.toLowerCase().contains(query) ?? false;

          return emailMatch || flatNumberMatch || flatCodeMatch;
        }

        return true;
      }).toList();

      _filteredUsers = filtered;

      // Re-group filtered users by building
      _groupFilteredUsersByBuilding();
    });
  }

  Map<String, List<UserData>> _filteredUsersByBuilding = {};

  void _groupFilteredUsersByBuilding() {
    _filteredUsersByBuilding.clear();
    for (var user in _filteredUsers) {
      final buildingCode = user.apartmentCode ?? 'Unknown';
      if (!_filteredUsersByBuilding.containsKey(buildingCode)) {
        _filteredUsersByBuilding[buildingCode] = [];
      }
      _filteredUsersByBuilding[buildingCode]!.add(user);
    }
    // Sort buildings by name
    final sortedBuildings = _filteredUsersByBuilding.keys.toList()..sort();
    final sortedMap = <String, List<UserData>>{};
    for (var code in sortedBuildings) {
      sortedMap[code] = _filteredUsersByBuilding[code]!;
    }
    _filteredUsersByBuilding = sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // AppBar removed - using parent AppBar from admin_dashboard_screen
      // appBar: AppBar(
      //   title: const Text('Users Management'),
      //   backgroundColor: AppColors.primary,
      //   elevation: 0,
      //   actions: [
      //     // Building selector (if multiple buildings)
      //     if (_allBuildings.length > 1)
      //       PopupMenuButton<String>(
      //         icon: const Icon(Icons.apartment),
      //         tooltip: 'Select Building',
      //         onSelected: (code) {
      //           setState(() {
      //             _selectedBuildingCode = code;
      //             StorageService.setString(
      //               AppConstants.selectedBuildingKey,
      //               code,
      //             );
      //           });
      //           _loadUsers();
      //         },
      //         itemBuilder: (context) => [
      //           const PopupMenuItem(
      //             value: 'all',
      //             child: Row(
      //               children: [
      //                 Icon(Icons.all_inclusive, size: 20),
      //                 SizedBox(width: 8),
      //                 Text('All Buildings'),
      //               ],
      //             ),
      //           ),
      //           const PopupMenuDivider(),
      //           ..._allBuildings.map(
      //             (building) => PopupMenuItem(
      //               value: building['code'],
      //               child: Row(
      //                 children: [
      //                   Icon(
      //                     _selectedBuildingCode == building['code']
      //                         ? Icons.check_circle
      //                         : Icons.circle_outlined,
      //                     size: 20,
      //                   ),
      //                   const SizedBox(width: 8),
      //                   Expanded(
      //                     child: Text(
      //                       building['name'] ?? 'Unknown',
      //                       overflow: TextOverflow.ellipsis,
      //                     ),
      //                   ),
      //                 ],
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     IconButton(
      //       icon: const Icon(Icons.add),
      //       tooltip: 'Add User',
      //       onPressed: () {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (_) => const CreateUserScreen()),
      //         ).then((_) => _loadUsers());
      //       },
      //     ),
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       tooltip: 'Refresh',
      //       onPressed: _loadUsers,
      //     ),
      //   ],
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Building Selector and Search Bar
                _buildHeaderSection(),
                // Users List Grouped by Building
                Expanded(child: _buildUsersListByBuilding()),
              ],
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Building Selector
          if (_allBuildings.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBuildingCode,
                  isExpanded: true,
                  icon: Icon(Icons.apartment, color: AppColors.primary),
                  hint: const Text('Select Building'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Row(
                        children: [
                          Icon(Icons.all_inclusive, size: 20),
                          SizedBox(width: 8),
                          Text('All Buildings'),
                        ],
                      ),
                    ),
                    ..._allBuildings.map((building) {
                      return DropdownMenuItem<String>(
                        value: building['code'],
                        child: Row(
                          children: [
                            Icon(
                              Icons.apartment,
                              size: 20,
                              color: _selectedBuildingCode == building['code']
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                building['name'] ??
                                    building['code'] ??
                                    'Unknown',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedBuildingCode == building['code'])
                              Icon(
                                Icons.check,
                                size: 18,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (String? code) {
                    setState(() {
                      _selectedBuildingCode = code;
                      if (code != null) {
                        StorageService.setString(
                          AppConstants.selectedBuildingKey,
                          code,
                        );
                      } else {
                        StorageService.remove(AppConstants.selectedBuildingKey);
                      }
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
          if (_allBuildings.length > 1) const SizedBox(height: 12),
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, phone, flat...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 12),
          // Role Filter
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'resident',
                label: Text('Residents'),
                icon: Icon(Icons.home, size: 18),
              ),
              ButtonSegment(
                value: 'staff',
                label: Text('Staff'),
                icon: Icon(Icons.work, size: 18),
              ),
            ],
            selected: {_selectedFilter},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedFilter = newSelection.first;
                _applyFilters();
              });
            },
          ),
          // Summary Info and 3D View Button
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_filteredUsers.length} ${_selectedFilter == 'resident' ? 'Residents' : 'Staff'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (_filteredUsersByBuilding.isNotEmpty)
                        Text(
                          '${_filteredUsersByBuilding.length} Building${_filteredUsersByBuilding.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 3D Building View Button
              if (_selectedBuildingCode != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BuildingView3DScreen(
                              buildingCode: _selectedBuildingCode,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.view_in_ar,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '3D View',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersListByBuilding() {
    if (_filteredUsers.isEmpty) {
      return UsersEmptyStateWidget(
        hasSearchQuery: _searchQuery.trim().isNotEmpty,
        searchQuery: _searchQuery.trim(),
        selectedFilter: _selectedFilter,
        onCreateUser: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserScreen()),
          ).then((_) => _loadUsers());
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredUsersByBuilding.length,
        itemBuilder: (context, index) {
          final buildingCode = _filteredUsersByBuilding.keys.elementAt(index);
          final buildingUsers = _filteredUsersByBuilding[buildingCode]!;
          final buildingName =
              _allBuildings.firstWhere(
                (b) => b['code'] == buildingCode,
                orElse: () => {'name': buildingCode},
              )['name'] ??
              buildingCode;
          final isExpanded = _expandedBuildings.contains(buildingCode);

          return _BuildingSection(
            buildingCode: buildingCode,
            buildingName: buildingName,
            users: buildingUsers,
            isExpanded: isExpanded,
            onToggle: () {
              setState(() {
                if (isExpanded) {
                  _expandedBuildings.remove(buildingCode);
                } else {
                  _expandedBuildings.add(buildingCode);
                }
              });
            },
            onUserTap: (user) => _showUserDetails(user),
          );
        },
      ),
    );
  }

  void _showUserDetails(UserData user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _UserDetailsSheet(user: user, allBuildings: _allBuildings),
    );
  }
}

class _BuildingSection extends StatelessWidget {
  final String buildingCode;
  final String buildingName;
  final List<UserData> users;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(UserData) onUserTap;

  const _BuildingSection({
    required this.buildingCode,
    required this.buildingName,
    required this.users,
    required this.isExpanded,
    required this.onToggle,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          // Building Header
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.apartment,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buildingName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${users.length} ${users.length == 1 ? 'user' : 'users'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          // Users List
          if (isExpanded)
            ...users.map(
              (user) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _UserCard(user: user, onTap: () => onUserTap(user)),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserData user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  void _navigateToChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2PChatScreen(
          receiverId: user.id,
          receiverName: user.fullName,
          receiverRole: user.role,
          receiverProfilePicture: user.profilePicture,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _navigateToComplaints(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintsManagementScreen(
          filterUserId: user.id,
          filterUserName: user.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isResident = user.role == 'resident';
    final isActive = user.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Card Content
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Profile Picture Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isResident
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [Colors.orange.shade400, Colors.orange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: user.profilePicture != null &&
                              user.profilePicture!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.profilePicture!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: Text(
                                  user.fullName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  user.fullName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                user.fullName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive
                                          ? Colors.green.shade600
                                          : Colors.orange.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user.phoneNumber,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (isResident && user.flatNumber != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 14,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Floor ${user.floorNumber} • Flat ${user.flatNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (user.flatType != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• ${user.flatType}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Action Buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                // View Details Button
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.shade200,
                ),
                // Send SMS/Chat Button
                Expanded(
                  child: InkWell(
                    onTap: () => _navigateToChat(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 18,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Send SMS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isResident) ...[
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey.shade200,
                  ),
                  // View Complaints Button (only for residents)
                  Expanded(
                    child: InkWell(
                      onTap: () => _navigateToComplaints(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Complaints',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDetailsSheet extends StatefulWidget {
  final UserData user;
  final List<Map<String, dynamic>> allBuildings;

  const _UserDetailsSheet({required this.user, required this.allBuildings});

  @override
  State<_UserDetailsSheet> createState() => _UserDetailsSheetState();
}

class _UserDetailsSheetState extends State<_UserDetailsSheet> {
  Map<String, dynamic>? _buildingDetails;
  bool _isLoadingBuilding = false;

  @override
  void initState() {
    super.initState();
    if (widget.user.apartmentCode != null) {
      _loadBuildingDetails();
    }
  }

  Future<void> _loadBuildingDetails() async {
    if (widget.user.apartmentCode == null) return;

    setState(() => _isLoadingBuilding = true);
    try {
      String buildingUrl = ApiConstants.adminBuildingDetails;
      buildingUrl = ApiConstants.addBuildingCode(
        buildingUrl,
        widget.user.apartmentCode,
      );
      final response = await ApiService.get(buildingUrl);

      if (response['success'] == true) {
        setState(() {
          _buildingDetails = response['data']?['building'];
          _isLoadingBuilding = false;
        });
      } else {
        setState(() => _isLoadingBuilding = false);
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading building details: $e');
      setState(() => _isLoadingBuilding = false);
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatFullDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isResident = widget.user.role == 'resident';
    final isActive = widget.user.status == 'active';
    final buildingInfo = widget.allBuildings.firstWhere(
      (b) => b['code'] == widget.user.apartmentCode,
      orElse: () => <String, dynamic>{},
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header with Avatar and Status
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isResident
                          ? [Colors.blue.shade50, Colors.blue.shade100]
                          : [Colors.orange.shade50, Colors.orange.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isResident
                                ? [Colors.blue.shade400, Colors.blue.shade600]
                                : [
                                    Colors.orange.shade400,
                                    Colors.orange.shade600,
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.user.fullName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
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
                              widget.user.fullName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.green.shade300
                                          : Colors.orange.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isActive
                                            ? Icons.check_circle
                                            : Icons.pending,
                                        size: 14,
                                        color: isActive
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.user.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isActive
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isResident
                                        ? Colors.blue.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isResident
                                          ? Colors.blue.shade300
                                          : Colors.orange.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isResident ? Icons.home : Icons.work,
                                        size: 14,
                                        color: isResident
                                            ? Colors.blue.shade700
                                            : Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.user.role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isResident
                                              ? Colors.blue.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.user.isOnline != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.user.isOnline == true
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.user.isOnline == true
                                        ? 'Online'
                                        : widget.user.lastSeen != null
                                        ? 'Last seen ${_formatDateTime(widget.user.lastSeen)}'
                                        : 'Offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Personal Information
                _DetailSection(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  color: Colors.blue,
                  children: [
                    _DetailRow(
                      label: 'Full Name',
                      value: widget.user.fullName,
                      icon: Icons.badge_outlined,
                    ),
                    _DetailRow(
                      label: 'Phone Number',
                      value: widget.user.phoneNumber,
                      icon: Icons.phone_outlined,
                      isPhone: true,
                    ),
                    if (widget.user.email != null)
                      _DetailRow(
                        label: 'Email',
                        value: widget.user.email!,
                        icon: Icons.email_outlined,
                        isEmail: true,
                      ),
                    _DetailRow(
                      label: 'User ID',
                      value: widget.user.id,
                      icon: Icons.fingerprint_outlined,
                      isCopyable: true,
                    ),
                  ],
                ),
                // Building Information
                if (widget.user.apartmentCode != null) ...[
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Building Information',
                    icon: Icons.apartment_outlined,
                    color: Colors.purple,
                    children: [
                      if (buildingInfo.isNotEmpty &&
                          buildingInfo['name'] != null)
                        _DetailRow(
                          label: 'Building Name',
                          value: buildingInfo['name'],
                          icon: Icons.business_outlined,
                        ),
                      _DetailRow(
                        label: 'Building Code',
                        value: widget.user.apartmentCode!,
                        icon: Icons.qr_code_outlined,
                        isCopyable: true,
                      ),
                      if (_buildingDetails != null) ...[
                        if (_buildingDetails!['address'] != null)
                          _DetailRow(
                            label: 'Address',
                            value: _formatAddress(_buildingDetails!['address']),
                            icon: Icons.location_on_outlined,
                          ),
                        if (_buildingDetails!['contact'] != null &&
                            _buildingDetails!['contact']['phone'] != null)
                          _DetailRow(
                            label: 'Building Phone',
                            value: _buildingDetails!['contact']['phone'],
                            icon: Icons.phone_outlined,
                          ),
                      ],
                    ],
                  ),
                ],
                // Flat Information (for residents)
                if (isResident && widget.user.flatNumber != null) ...[
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Flat Information',
                    icon: Icons.home_outlined,
                    color: Colors.green,
                    children: [
                      if (widget.user.wing != null)
                        _DetailRow(
                          label: 'Wing',
                          value: widget.user.wing!,
                          icon: Icons.architecture_outlined,
                        ),
                      if (widget.user.floorNumber != null)
                        _DetailRow(
                          label: 'Floor Number',
                          value: 'Floor ${widget.user.floorNumber}',
                          icon: Icons.layers_outlined,
                        ),
                      if (widget.user.flatNumber != null)
                        _DetailRow(
                          label: 'Flat Number',
                          value: widget.user.flatNumber!,
                          icon: Icons.door_front_door_outlined,
                        ),
                      if (widget.user.flatCode != null)
                        _DetailRow(
                          label: 'Flat Code',
                          value: widget.user.flatCode!,
                          icon: Icons.qr_code_2_outlined,
                          isCopyable: true,
                        ),
                      if (widget.user.flatType != null)
                        _DetailRow(
                          label: 'Flat Type',
                          value: widget.user.flatType!,
                          icon: Icons.category_outlined,
                        ),
                    ],
                  ),
                ],
                // Account Information
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Account Information',
                  icon: Icons.account_circle_outlined,
                  color: Colors.orange,
                  children: [
                    if (widget.user.registeredAt != null)
                      _DetailRow(
                        label: 'Registered On',
                        value: _formatFullDateTime(widget.user.registeredAt),
                        icon: Icons.calendar_today_outlined,
                        subtitle: _formatDateTime(widget.user.registeredAt),
                      ),
                    if (widget.user.lastUpdatedAt != null)
                      _DetailRow(
                        label: 'Last Updated',
                        value: _formatFullDateTime(widget.user.lastUpdatedAt),
                        icon: Icons.update_outlined,
                        subtitle: _formatDateTime(widget.user.lastUpdatedAt),
                      ),
                    if (widget.user.isOnline != null)
                      _DetailRow(
                        label: 'Online Status',
                        value: widget.user.isOnline == true
                            ? 'Currently Online'
                            : widget.user.lastSeen != null
                            ? 'Last seen ${_formatDateTime(widget.user.lastSeen)}'
                            : 'Offline',
                        icon: widget.user.isOnline == true
                            ? Icons.circle
                            : Icons.circle_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    // Send SMS/Chat Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => P2PChatScreen(
                                receiverId: widget.user.id,
                                receiverName: widget.user.fullName,
                                receiverRole: widget.user.role,
                                receiverProfilePicture: widget.user.profilePicture,
                              ),
                              fullscreenDialog: true,
                            ),
                          );
                        },
                        icon: Icon(Icons.message_outlined, color: Colors.green.shade600),
                        label: Text(
                          'Send SMS',
                          style: TextStyle(color: Colors.green.shade600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.green.shade300, width: 1.5),
                        ),
                      ),
                    ),
                    if (isResident) ...[
                      const SizedBox(width: 12),
                      // View Complaints Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ComplaintsManagementScreen(
                                  filterUserId: widget.user.id,
                                  filterUserName: widget.user.fullName,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.description_outlined, color: Colors.orange.shade600),
                          label: Text(
                            'Complaints',
                            style: TextStyle(color: Colors.orange.shade600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.orange.shade300, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'N/A';
    final parts = <String>[];
    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['pincode'] != null) parts.add(address['pincode']);
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color color;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: color),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final bool isPhone;
  final bool isEmail;
  final bool isCopyable;

  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.isPhone = false,
    this.isEmail = false,
    this.isCopyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
          ],
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isCopyable)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // Copy to clipboard functionality can be added here
                        },
                      ),
                    if (isPhone)
                      IconButton(
                        icon: const Icon(Icons.phone, size: 18),
                        color: Colors.green,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // Make phone call functionality can be added here
                        },
                      ),
                    if (isEmail)
                      IconButton(
                        icon: const Icon(Icons.email, size: 18),
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // Send email functionality can be added here
                        },
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
