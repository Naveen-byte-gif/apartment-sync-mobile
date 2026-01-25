import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../complaints/complaint_detail_screen.dart';
import 'admin_complaint_detail_screen.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/complaint_filter_mega_menu.dart';

class ComplaintsManagementScreen extends StatefulWidget {
  final String? filterUserId;
  final String? filterUserName;

  const ComplaintsManagementScreen({
    super.key,
    this.filterUserId,
    this.filterUserName,
  });

  @override
  State<ComplaintsManagementScreen> createState() =>
      ComplaintsManagementScreenState();
}

class ComplaintsManagementScreenState
    extends State<ComplaintsManagementScreen> {
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedCategory = 'all';
  String _selectedPriority = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;
  final TextEditingController _searchController = TextEditingController();
  String? _userRole;

  void toggleFilters() {
    _showFilterMegaMenu();
  }

  Future<void> _showFilterMegaMenu() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComplaintFilterMegaMenu(
        selectedStatus: _selectedStatus,
        selectedCategory: _selectedCategory,
        selectedPriority: _selectedPriority,
        startDate: _startDate,
        endDate: _endDate,
        activeFilterCount: _getActiveFilterCount(),
        onStatusChanged: (value) {
          setState(() {
            _selectedStatus = value;
            _applyFilters();
          });
        },
        onCategoryChanged: (value) {
          setState(() {
            _selectedCategory = value;
            _applyFilters();
          });
        },
        onPriorityChanged: (value) {
          setState(() {
            _selectedPriority = value;
            _applyFilters();
          });
        },
        onDateRangeSelected: (start, end) {
          setState(() {
            _startDate = start;
            _endDate = end;
            _applyFilters();
          });
        },
        onClearAll: () {
          _clearFilters();
          Navigator.pop(context);
        },
        onApply: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void refreshComplaints() {
    _loadComplaints();
  }

  String? _getUserRole() {
    try {
      final userJson = StorageService.getString(AppConstants.userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        return userData['role']?.toString();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error getting user role: $e');
    }
    return null;
  }

  bool get _isStaff => _getUserRole() == 'staff';
  bool get _isAdmin => _getUserRole() == 'admin';

  @override
  void initState() {
    super.initState();
    _userRole = _getUserRole();
    _loadBuildings();
    _loadComplaints();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    try {
      final buildingsEndpoint = _isStaff 
          ? ApiConstants.staffBuildings 
          : ApiConstants.adminBuildings;
      final response = await ApiService.get(buildingsEndpoint);
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
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
    }
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for admin complaints');
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);

          socketService.on('complaint_created', (data) {
            print('📡 [FLUTTER] Complaint created event received');
            if (mounted) {
              _loadComplaints();
            }
          });

          socketService.on('complaint_updated', (data) {
            print('📡 [FLUTTER] Complaint updated event received');
            if (mounted) {
              _loadComplaints();
            }
          });

          socketService.on('status_updated', (data) {
            print('📡 [FLUTTER] Status updated event received');
            if (mounted) {
              _loadComplaints();
            }
          });

          socketService.on('ticket_status_updated', (data) {
            print('📡 [FLUTTER] Ticket status updated event received');
            if (mounted) {
              _loadComplaints();
            }
          });
        }
      } catch (e) {
        print('❌ [FLUTTER] Error setting up socket: $e');
      }
    }
  }

  Future<void> _loadComplaints() async {
    print('🖱️ [FLUTTER] Loading complaints...');
    setState(() => _isLoading = true);
    try {
      String endpoint = _isStaff 
          ? ApiConstants.staffComplaints 
          : ApiConstants.adminComplaints;
      if (_selectedBuildingCode != null) {
        endpoint = ApiConstants.addBuildingCode(
          endpoint,
          _selectedBuildingCode,
        );
      }
      final response = await ApiService.get(endpoint);
      print('✅ [FLUTTER] Complaints response received');

      if (response['success'] == true) {
        final complaintsList = response['data']?['complaints'] as List?;

        if (complaintsList != null) {
          setState(() {
            // Convert and sort complaints by latest first (updatedAt or createdAt)
            final complaints = complaintsList.cast<Map<String, dynamic>>();
            _complaints = complaints.toList()
              ..sort((a, b) {
                DateTime? dateA;
                DateTime? dateB;

                // Try to get updatedAt first, fallback to createdAt
                try {
                  if (a['updatedAt'] != null) {
                    dateA = DateTime.parse(a['updatedAt'].toString());
                  } else if (a['createdAt'] != null) {
                    dateA = DateTime.parse(a['createdAt'].toString());
                  }
                } catch (e) {
                  dateA = null;
                }

                try {
                  if (b['updatedAt'] != null) {
                    dateB = DateTime.parse(b['updatedAt'].toString());
                  } else if (b['createdAt'] != null) {
                    dateB = DateTime.parse(b['createdAt'].toString());
                  }
                } catch (e) {
                  dateB = null;
                }

                // Sort descending (newest first)
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });

            _applyFilters();
          });
          print('✅ [FLUTTER] Loaded ${_complaints.length} complaints');
        }
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading complaints: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading complaints: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredComplaints = _complaints.where((complaint) {
        // User filter (filter by specific user ID)
        if (widget.filterUserId != null && widget.filterUserId!.isNotEmpty) {
          final createdBy = complaint['createdBy'];
          String? complaintUserId;
          if (createdBy is String) {
            complaintUserId = createdBy;
          } else if (createdBy is Map) {
            complaintUserId =
                createdBy['_id']?.toString() ?? createdBy['id']?.toString();
          }
          if (complaintUserId != widget.filterUserId) {
            return false;
          }
        }

        // Status filter
        if (_selectedStatus != 'all' &&
            complaint['status'] != _selectedStatus) {
          return false;
        }
        // Category filter
        if (_selectedCategory != 'all' &&
            complaint['category'] != _selectedCategory) {
          return false;
        }
        // Priority filter
        if (_selectedPriority != 'all' &&
            complaint['priority'] != _selectedPriority) {
          return false;
        }
        // Date range filter
        if (_startDate != null || _endDate != null) {
          final createdAt = complaint['createdAt'] != null
              ? DateTime.parse(complaint['createdAt'].toString())
              : null;
          if (createdAt != null) {
            if (_startDate != null && createdAt.isBefore(_startDate!)) {
              return false;
            }
            if (_endDate != null &&
                createdAt.isAfter(_endDate!.add(const Duration(days: 1)))) {
              return false;
            }
          }
        }
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          return (complaint['title']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false) ||
              (complaint['ticketNumber']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false) ||
              (complaint['createdBy']?['fullName']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false);
        }
        return true;
      }).toList();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.red;
      case 'assigned':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'cancelled':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  String _formatSLA(DateTime? createdAt) {
    if (createdAt == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  List<String> _getUniqueWings() {
    final wings = <String>{};
    for (var complaint in _complaints) {
      final createdBy = complaint['createdBy'] ?? {};
      if (createdBy['wing'] != null) {
        wings.add(createdBy['wing']);
      }
    }
    return wings.toList()..sort();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedCategory = 'all';
      _selectedPriority = 'all';
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
      _applyFilters();
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedStatus != 'all') count++;
    if (_selectedCategory != 'all') count++;
    if (_selectedPriority != 'all') count++;
    if (_startDate != null || _endDate != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  List<String> _getUniqueBuildingCodes() {
    final buildingCodes = <String>[];
    for (var complaint in _complaints) {
      final createdBy = complaint['createdBy'] ?? {};
      final apartmentCode = createdBy['apartmentCode']?.toString();
      if (apartmentCode != null && !buildingCodes.contains(apartmentCode)) {
        buildingCodes.add(apartmentCode);
      }
    }
    // Sort by building name for better UX
    buildingCodes.sort((codeA, codeB) {
      final buildingA = _allBuildings.firstWhere(
        (building) => building['code'] == codeA,
        orElse: () => {'name': codeA},
      );
      final buildingB = _allBuildings.firstWhere(
        (building) => building['code'] == codeB,
        orElse: () => {'name': codeB},
      );
      return (buildingA['name'] ?? codeA).toString().compareTo(
        (buildingB['name'] ?? codeB).toString(),
      );
    });
    return buildingCodes;
  }

  Future<void> _showBuildingSelector() async {
    if (_allBuildings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No buildings available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BuildingSelectorSheet(
        buildings: _allBuildings,
        selectedBuildingCode: _selectedBuildingCode,
      ),
    );

    if (selectedCode != null && selectedCode != _selectedBuildingCode) {
      setState(() {
        _selectedBuildingCode = selectedCode;
        StorageService.setString(
          AppConstants.selectedBuildingKey,
          selectedCode,
        );
      });
      _loadComplaints();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get building name for sidebar
    final buildingName =
        _selectedBuildingCode != null && _allBuildings.isNotEmpty
        ? _allBuildings.firstWhere(
                (b) => b['code'] == _selectedBuildingCode,
                orElse: () => {'name': ''},
              )['name'] ??
              ''
        : null;

    final activeFilterCount = _getActiveFilterCount();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppSidebarBuilder.buildAdminSidebar(
        context: context,
        buildingName: buildingName,
        buildings: _allBuildings,
        selectedBuildingCode: _selectedBuildingCode,
        onBuildingSelected: (code) {
          setState(() {
            _selectedBuildingCode = code;
            StorageService.setString(AppConstants.selectedBuildingKey, code);
          });
          _loadComplaints();
        },
      ),
      appBar: AppBar(
        title: Text(
          widget.filterUserName != null
              ? '${widget.filterUserName}\'s Complaints'
              : 'Complaints Management',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (activeFilterCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '$activeFilterCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              activeFilterCount > 0
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: toggleFilters,
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaints,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
              AppColors.background,
            ],
          ),
        ),
        child: Column(
          children: [
            // Top Section - Building & Search
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // Building Selector - Minimalist Design
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showBuildingSelector,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    buildingName ?? 'Select Building',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: buildingName != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (buildingName != null)
                                    Text(
                                      'Tap to change',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar - Compact Design
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.3),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController
                              ..text = _searchQuery
                              ..selection = TextSelection.collapsed(
                                offset: _searchQuery.length,
                              ),
                            decoration: InputDecoration(
                              hintText: 'Search complaints...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withOpacity(0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _applyFilters();
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _applyFilters();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filter Toggle Button
                      Container(
                        decoration: BoxDecoration(
                          color: _getActiveFilterCount() > 0
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getActiveFilterCount() > 0
                                ? AppColors.primary
                                : AppColors.border.withOpacity(0.3),
                          ),
                        ),
                        child: Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.tune_rounded,
                                color: _getActiveFilterCount() > 0
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              onPressed: toggleFilters,
                              tooltip: 'Filters',
                            ),
                            if (_getActiveFilterCount() > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_getActiveFilterCount()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status Segmented Control - Modern Design
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusSegment(
                      label: 'All',
                      count: _filteredComplaints.length,
                      isSelected: _selectedStatus == 'all',
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'all';
                          _applyFilters();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _StatusSegment(
                      label: 'Open',
                      count: _filteredComplaints
                          .where(
                            (c) =>
                                (c['status']?.toString() ?? '').toLowerCase() ==
                                'open',
                          )
                          .length,
                      isSelected: _selectedStatus == 'Open',
                      color: Colors.red,
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'Open';
                          _applyFilters();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _StatusSegment(
                      label: 'Progress',
                      count: _filteredComplaints.where((c) {
                        final status = (c['status']?.toString() ?? '')
                            .toLowerCase();
                        return status == 'in progress' || status == 'assigned';
                      }).length,
                      isSelected: _selectedStatus == 'In Progress',
                      color: Colors.blue,
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'In Progress';
                          _applyFilters();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _StatusSegment(
                      label: 'Resolved',
                      count: _filteredComplaints
                          .where(
                            (c) =>
                                (c['status']?.toString() ?? '').toLowerCase() ==
                                'resolved',
                          )
                          .length,
                      isSelected: _selectedStatus == 'Resolved',
                      color: Colors.green,
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'Resolved';
                          _applyFilters();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _StatusSegment(
                      label: 'Closed',
                      count: _filteredComplaints
                          .where(
                            (c) =>
                                (c['status']?.toString() ?? '').toLowerCase() ==
                                'closed',
                          )
                          .length,
                      isSelected: _selectedStatus == 'Closed',
                      color: Colors.grey,
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'Closed';
                          _applyFilters();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Complaints List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredComplaints.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inbox_rounded,
                                size: 60,
                                color: AppColors.primary.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Complaints',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getActiveFilterCount() > 0
                                  ? 'No results match your filters'
                                  : 'Start managing complaints',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (_getActiveFilterCount() > 0) ...[
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Reset Filters'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadComplaints,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredComplaints.length,
                        itemBuilder: (context, index) {
                          final complaintRaw = _filteredComplaints[index];
                          final complaint = complaintRaw is Map
                              ? Map<String, dynamic>.from(complaintRaw)
                              : <String, dynamic>{};
                          final status =
                              complaint['status']?.toString() ?? 'Unknown';
                          final statusColor = _getStatusColor(status);
                          final createdByRaw = complaint['createdBy'];
                          final createdBy = createdByRaw is Map
                              ? Map<String, dynamic>.from(createdByRaw)
                              : <String, dynamic>{};
                          final assignedToRaw = complaint['assignedTo'];
                          final assignedTo = assignedToRaw is Map
                              ? Map<String, dynamic>.from(assignedToRaw)
                              : <String, dynamic>{};
                          final staffRaw = assignedTo['staff'];
                          final staff = staffRaw is Map
                              ? Map<String, dynamic>.from(staffRaw)
                              : <String, dynamic>{};
                          final userRaw = staff['user'];
                          final assignedStaff = userRaw is Map
                              ? Map<String, dynamic>.from(userRaw)
                              : <String, dynamic>{};
                          final createdAt = complaint['createdAt'] != null
                              ? DateTime.parse(
                                  complaint['createdAt'].toString(),
                                )
                              : null;
                          final updatedAt = complaint['updatedAt'] != null
                              ? DateTime.parse(
                                  complaint['updatedAt'].toString(),
                                )
                              : null;

                          return _PremiumComplaintCard(
                            complaint: complaint,
                            status: status,
                            statusColor: statusColor,
                            createdBy: createdBy,
                            assignedStaff: assignedStaff,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminComplaintDetailScreen(
                                    complaintId:
                                        complaint['_id']?.toString() ??
                                        complaint['id']?.toString() ??
                                        '',
                                  ),
                                ),
                              ).then((_) => _loadComplaints());
                            },
                            formatSLA: _formatSLA,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Premium Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final Function(String) onChanged;
  final String Function(String)? getDisplayName;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.getDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'all';
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${value == 'all' ? 'All' : (getDisplayName != null ? getDisplayName!(value) : value)}',
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => options.map((option) {
        final isSelected = value == option;
        final displayText = option == 'all'
            ? 'All'
            : (getDisplayName != null ? getDisplayName!(option) : option);
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              if (isSelected)
                const Icon(Icons.check, color: AppColors.primary, size: 18)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(displayText),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Premium Complaint Card Widget
class _PremiumComplaintCard extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final String status;
  final Color statusColor;
  final Map<String, dynamic> createdBy;
  final Map<String, dynamic> assignedStaff;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VoidCallback onTap;
  final String Function(DateTime?) formatSLA;

  const _PremiumComplaintCard({
    required this.complaint,
    required this.status,
    required this.statusColor,
    required this.createdBy,
    required this.assignedStaff,
    required this.createdAt,
    required this.updatedAt,
    required this.onTap,
    required this.formatSLA,
  });

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'emergency':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppColors.info;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'electrical':
        return Icons.flash_on;
      case 'plumbing':
        return Icons.water_drop;
      case 'carpentry':
        return Icons.build;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'security':
        return Icons.security;
      default:
        return Icons.category;
    }
  }

  static String? _getProfilePictureUrl(Map<String, dynamic> userData) {
    try {
      final profilePicture = userData['profilePicture'];
      if (profilePicture == null) return null;

      // If it's a string, return it directly (after trimming)
      if (profilePicture is String) {
        final url = profilePicture.trim();
        return url.isNotEmpty ? url : null;
      }

      // If it's a Map, extract the URL
      if (profilePicture is Map) {
        final url = profilePicture['url']?.toString()?.trim();
        return url != null && url.isNotEmpty ? url : null;
      }

      return null;
    } catch (e) {
      print('❌ [FLUTTER] Error extracting profile picture URL: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = complaint['priority'];
    final category = complaint['category'];
    final priorityColor = _getPriorityColor(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.surface,
                statusColor.withOpacity(0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title, Ticket, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.confirmation_number,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ticket: ${complaint['ticketNumber'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1.5),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category, Priority, Location Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (priority != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: priorityColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, size: 14, color: priorityColor),
                          const SizedBox(width: 6),
                          Text(
                            priority,
                            style: TextStyle(
                              fontSize: 12,
                              color: priorityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (createdBy['wing'] != null ||
                      createdBy['flatNumber'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${createdBy['wing'] ?? ''}${createdBy['wing'] != null && createdBy['flatNumber'] != null ? '-' : ''}${createdBy['flatNumber'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Divider
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withOpacity(0.5),
              ),
              const SizedBox(height: 12),

              // Footer: Resident, Staff, SLA, Updated
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final profilePicUrl =
                                    _PremiumComplaintCard._getProfilePictureUrl(
                                      createdBy,
                                    );
                                return CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.primary
                                      .withOpacity(0.1),
                                  backgroundImage: profilePicUrl != null
                                      ? NetworkImage(profilePicUrl)
                                      : null,
                                  onBackgroundImageError: profilePicUrl != null
                                      ? (exception, stackTrace) {
                                          // Image failed to load, will show child instead
                                          print(
                                            '❌ [FLUTTER] Failed to load profile picture: $exception',
                                          );
                                        }
                                      : null,
                                  child: profilePicUrl == null
                                      ? Text(
                                          (createdBy['fullName'] ?? 'U')[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    createdBy['fullName'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (assignedStaff['fullName'] != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.engineering,
                                          size: 12,
                                          color: AppColors.info,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            assignedStaff['fullName'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.info,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (createdAt != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatSLA(createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (updatedAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMM d, h:mm a').format(updatedAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Status Segment Widget - Modern Tab Design
class _StatusSegment extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusSegment({
    required this.label,
    required this.count,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final segmentColor = color ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? segmentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? segmentColor
                  : AppColors.border.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : segmentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : segmentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Building Selector Sheet - Modern Design
class _BuildingSelectorSheet extends StatelessWidget {
  final List<Map<String, dynamic>> buildings;
  final String? selectedBuildingCode;

  const _BuildingSelectorSheet({
    required this.buildings,
    this.selectedBuildingCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Icon(
                  Icons.location_city_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Building',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose building to view',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Buildings List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: buildings.length,
              itemBuilder: (context, index) {
                final building = buildings[index];
                final code = building['code']?.toString() ?? '';
                final name = building['name']?.toString() ?? code;
                final isSelected = code == selectedBuildingCode;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, code),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.apartment_rounded,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (code.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      code,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.8)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Filter Mega Menu moved to separate file: complaint_filter_mega_menu.dart
