import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import '../../widgets/users_empty_state_widget.dart';
import 'create_user_screen.dart';
import 'dart:convert';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<UserData> _users = [];
  List<UserData> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'resident'; // resident, staff (removed 'all')
  String _searchQuery = '';
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;

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
    final currentStoredCode = StorageService.getString(AppConstants.selectedBuildingKey);
    if (currentStoredCode != _selectedBuildingCode && currentStoredCode != null) {
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
            final storedCode = StorageService.getString(AppConstants.selectedBuildingKey);
            
            // Check if stored code exists in the fetched buildings
            final isValidCode = storedCode != null && 
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
      String usersUrl = ApiConstants.adminUsers;
      if (_selectedBuildingCode != null) {
        usersUrl = ApiConstants.addBuildingCode(
          usersUrl,
          _selectedBuildingCode,
        );
      }
      final response = await ApiService.get(usersUrl);
      print('✅ [FLUTTER] Users response received');

      if (response['success'] == true) {
        final usersList = response['data']?['users'] as List?;
        if (usersList != null) {
          setState(() {
            _users = usersList.map((u) => UserData.fromJson(u)).toList();
            _statistics = response['data']?['statistics'];
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

  /// Efficiently filter users for large datasets (550+ users)
  /// Uses optimized string matching with case-insensitive search
  void _applyFilters() {
    setState(() {
      final query = _searchQuery.trim().toLowerCase();
      final isSearchActive = query.isNotEmpty;
      
      _filteredUsers = _users.where((user) {
        // Role filter (required - no 'all' option)
        if (user.role != _selectedFilter) {
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
          final flatNumberMatch = user.flatNumber?.toLowerCase().contains(query) ?? false;
          final flatCodeMatch = user.flatCode?.toLowerCase().contains(query) ?? false;
          
          return emailMatch || flatNumberMatch || flatCodeMatch;
        }
        
        return true;
      }).toList();
    });
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
                // Statistics Cards
                if (_statistics != null) _buildStatisticsCards(),
                // Search and Filter Bar
                _buildSearchAndFilter(),
                // Users List
                Expanded(child: _buildUsersList()),
              ],
            ),
    );
  }

  Widget _buildStatisticsCards() {
    final stats = _statistics!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: GridView.count(
        crossAxisCount: 2, // 👈 2 per row
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4, // adjust if needed
        children: [
          _StatCard(
            title: 'Total Users',
            value: '${_users.length}',
            icon: Icons.people,
            color: Colors.white,
          ),
          _StatCard(
            title: 'Residents',
            value: '${stats['residents'] ?? 0}',
            icon: Icons.home,
            color: Colors.white,
          ),
          _StatCard(
            title: 'Staff',
            value: '${stats['staff'] ?? 0}',
            icon: Icons.work,
            color: Colors.white,
          ),
          _StatCard(
            title: 'Active',
            value: '${stats['active'] ?? 0}',
            icon: Icons.check_circle,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name flat...',
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
        ],
      ),
    );
  }

  Widget _buildUsersList() {
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
        padding: const EdgeInsets.all(16),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _UserCard(user: user, onTap: () => _showUserDetails(user));
        },
      ),
    );
  }

  void _showUserDetails(UserData user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailsSheet(user: user),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final isResident = user.role == 'resident';
    final isActive = user.status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
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
                ),
                child: Center(
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
              const SizedBox(width: 16),
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
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                          ),
                          child: Text(
                            user.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isResident ? Icons.home : Icons.work,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            user.phoneNumber,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (user.email != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isResident && user.flatNumber != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.apartment,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Floor ${user.floorNumber} - Flat ${user.flatNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            if (user.flatType != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.flatType!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserDetailsSheet extends StatelessWidget {
  final UserData user;

  const _UserDetailsSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final isResident = user.role == 'resident';
    final isActive = user.status == 'active';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
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
                      ),
                      child: Center(
                        child: Text(
                          user.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
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
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Details
                _DetailSection(
                  title: 'Personal Information',
                  icon: Icons.person,
                  children: [
                    _DetailRow(label: 'Full Name', value: user.fullName),
                    _DetailRow(label: 'Phone Number', value: user.phoneNumber),
                    if (user.email != null)
                      _DetailRow(label: 'Email', value: user.email!),
                    _DetailRow(label: 'Role', value: user.role.toUpperCase()),
                  ],
                ),
                if (isResident) ...[
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Flat Information',
                    icon: Icons.apartment,
                    children: [
                      if (user.floorNumber != null)
                        _DetailRow(
                          label: 'Floor',
                          value: user.floorNumber.toString(),
                        ),
                      if (user.flatNumber != null)
                        _DetailRow(
                          label: 'Flat Number',
                          value: user.flatNumber!,
                        ),
                      if (user.flatCode != null)
                        _DetailRow(label: 'Flat Code', value: user.flatCode!),
                      if (user.flatType != null)
                        _DetailRow(label: 'Flat Type', value: user.flatType!),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
