import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import '../admin/create_user_screen.dart';
import 'create_user_screen.dart' as staff_create;
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class StaffUsersManagementScreen extends StatefulWidget {
  const StaffUsersManagementScreen({super.key});

  @override
  State<StaffUsersManagementScreen> createState() => _StaffUsersManagementScreenState();
}

class _StaffUsersManagementScreenState extends State<StaffUsersManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  Map<String, List<Map<String, dynamic>>> _usersByBuilding = {};
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'resident';
  String _searchQuery = '';
  List<Map<String, dynamic>> _assignedBuildings = [];
  String? _selectedBuildingCode;
  Set<String> _expandedBuildings = {};
  Map<String, dynamic>? _permissions;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadAssignedBuildings();
    _setupSocketListeners();
  }

  void _loadPermissions() {
    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        // Get permissions from staff dashboard data if available
        // Or from stored staff data
      }
    } catch (e) {
      print('Error loading permissions: $e');
    }
  }

  bool get _canManageAccess {
    return _permissions?['canManageAccess'] == true;
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for staff users');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          socketService.on('user_created', (data) {
            if (mounted) {
              _loadUsers();
              AppMessageHandler.showSuccess(context, 'New user added');
            }
          });

          socketService.on('user_updated', (data) {
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

  Future<void> _loadAssignedBuildings() async {
    try {
      final response = await ApiService.get(ApiConstants.staffBuildings);
      if (response['success'] == true) {
        setState(() {
          _assignedBuildings = List<Map<String, dynamic>>.from(
            response['data']?['buildings'] ?? [],
          );

          if (_assignedBuildings.isNotEmpty) {
            final storedCode = StorageService.getString(
              AppConstants.selectedBuildingKey,
            );
            
            final isValidCode = storedCode != null &&
                _assignedBuildings.any((b) => b['code'] == storedCode);

            if (isValidCode) {
              _selectedBuildingCode = storedCode;
            } else {
              final primaryBuilding = _assignedBuildings.firstWhere(
                (b) => b['isPrimary'] == true,
                orElse: () => _assignedBuildings.first,
              );
              _selectedBuildingCode = primaryBuilding['code'];
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
    print('🖱️ [FLUTTER] Loading staff users...');
    setState(() => _isLoading = true);
    try {
      String usersUrl = ApiConstants.staffUsers;
      if (_selectedBuildingCode != null) {
        usersUrl = '$usersUrl?buildingCode=$_selectedBuildingCode';
      }
      
      final response = await ApiService.get(usersUrl);
      print('✅ [FLUTTER] Staff users response received');

      if (response['success'] == true) {
        final usersList = response['data']?['users'] as List?;
        if (usersList != null) {
          setState(() {
            _users = usersList.map((u) => u as Map<String, dynamic>).toList();
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
      final buildingCode = user['apartmentCode'] ?? 'Unknown';
      if (!_usersByBuilding.containsKey(buildingCode)) {
        _usersByBuilding[buildingCode] = [];
      }
      _usersByBuilding[buildingCode]!.add(user);
    }
    
    // Sort buildings
    final sortedBuildings = _usersByBuilding.keys.toList()..sort();
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (var code in sortedBuildings) {
      sortedMap[code] = _usersByBuilding[code]!;
    }
    _usersByBuilding = sortedMap;

    // Auto-expand first building
    if (_usersByBuilding.length == 1) {
      _expandedBuildings.add(_usersByBuilding.keys.first);
    }
  }

  void _applyFilters() {
    setState(() {
      final query = _searchQuery.trim().toLowerCase();
      
      var filtered = _users.where((user) {
        // Role filter
        if (_selectedFilter != 'all') {
          if (user['role']?.toLowerCase() != _selectedFilter.toLowerCase()) {
            return false;
          }
        }

        // Search filter
        if (query.isNotEmpty) {
          final name = (user['fullName'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final phone = (user['phoneNumber'] ?? '').toString();
          final flat = (user['flatNumber'] ?? '').toString().toLowerCase();
          
          return name.contains(query) ||
              email.contains(query) ||
              phone.contains(query) ||
              flat.contains(query);
        }

        return true;
      }).toList();

      _filteredUsers = filtered;
      _groupFilteredUsersByBuilding();
    });
  }

  Map<String, List<Map<String, dynamic>>> _filteredUsersByBuilding = {};

  void _groupFilteredUsersByBuilding() {
    _filteredUsersByBuilding.clear();
    for (var user in _filteredUsers) {
      final buildingCode = user['apartmentCode'] ?? 'Unknown';
      if (!_filteredUsersByBuilding.containsKey(buildingCode)) {
        _filteredUsersByBuilding[buildingCode] = [];
      }
      _filteredUsersByBuilding[buildingCode]!.add(user);
    }
    
    final sortedBuildings = _filteredUsersByBuilding.keys.toList()..sort();
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (var code in sortedBuildings) {
      sortedMap[code] = _filteredUsersByBuilding[code]!;
    }
    _filteredUsersByBuilding = sortedMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Users Management'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_canManageAccess)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Resident',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const staff_create.StaffCreateUserScreen(),
                  ),
                );
                if (mounted) _loadUsers();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedBuildings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No buildings assigned',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please contact admin to assign buildings',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
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
          if (_assignedBuildings.length > 1)
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
                  items: _assignedBuildings.map((building) {
                    return DropdownMenuItem<String>(
                      value: building['code'],
                      child: Row(
                        children: [
                          if (building['isPrimary'] == true)
                            Icon(Icons.star, size: 16, color: AppColors.warning),
                          if (building['isPrimary'] == true)
                            const SizedBox(width: 8),
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
                              building['name'] ?? building['code'] ?? 'Unknown',
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
                  }).toList(),
                  onChanged: (String? code) {
                    setState(() {
                      _selectedBuildingCode = code;
                      if (code != null) {
                        StorageService.setString(
                          AppConstants.selectedBuildingKey,
                          code,
                        );
                      }
                      _applyFilters();
                    });
                    _loadUsers();
                  },
                ),
              ),
            ),
          if (_assignedBuildings.length > 1) const SizedBox(height: 12),
          
          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'resident', 'staff'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter.toUpperCase()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          
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
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsersListByBuilding() {
    if (_filteredUsersByBuilding.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No users found matching "$_searchQuery"'
                  : 'No users found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _filteredUsersByBuilding.length,
        itemBuilder: (context, index) {
          final buildingCode = _filteredUsersByBuilding.keys.elementAt(index);
          final building = _assignedBuildings.firstWhere(
            (b) => b['code'] == buildingCode,
            orElse: () => {'name': buildingCode, 'code': buildingCode},
          );
          final users = _filteredUsersByBuilding[buildingCode]!;
          final isExpanded = _expandedBuildings.contains(buildingCode);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              leading: Icon(
                Icons.apartment,
                color: AppColors.primary,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      building['name'] ?? buildingCode,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${users.length} ${users.length == 1 ? 'user' : 'users'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text('Code: $buildingCode'),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedBuildings.add(buildingCode);
                  } else {
                    _expandedBuildings.remove(buildingCode);
                  }
                });
              },
              children: users.map((user) {
                return _buildUserListItem(user);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final role = user['role'] ?? 'unknown';
    final status = user['status'] ?? 'pending';
    final flatNumber = user['flatNumber'] ?? 'N/A';
    final floorNumber = user['floorNumber'] ?? 'N/A';
    final wing = user['wing'] ?? 'A';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        break;
      case 'suspended':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = Colors.grey;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: role == 'resident'
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.info.withOpacity(0.1),
        child: Text(
          (user['fullName']?[0] ?? 'U').toUpperCase(),
          style: TextStyle(
            color: role == 'resident' ? AppColors.primary : AppColors.info,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user['fullName'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role == 'resident')
            Text(
              '$wing-$flatNumber, Floor $floorNumber',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            Text(
              'Staff Member',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (role == 'resident'
                          ? AppColors.primary
                          : AppColors.info)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: role == 'resident'
                        ? AppColors.primary
                        : AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          _showUserActions(user);
        },
      ),
      onTap: () {
        // Show user details or navigate to detail screen
      },
    );
  }

  void _showUserActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to user details
                },
              ),
              if (_canManageAccess && user['role'] == 'resident')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit User'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to edit user
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.chat,
                  color: AppColors.primary,
                ),
                title: const Text('Send Message'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to chat
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

