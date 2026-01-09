import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../complaints/complaint_detail_screen.dart';
import 'admin_complaint_detail_screen.dart';
import '../../widgets/app_sidebar.dart';

class ComplaintsManagementScreen extends StatefulWidget {
  const ComplaintsManagementScreen({super.key});

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
  String _selectedWing = 'all';
  String _selectedBuildingFilter = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;
  List<Map<String, dynamic>> _allBuildings = [];
  String? _selectedBuildingCode;
  final TextEditingController _searchController = TextEditingController();

  void toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void refreshComplaints() {
    _loadComplaints();
  }

  // Statistics
  Map<String, int> _statistics = {
    'total': 0,
    'open': 0,
    'inProgress': 0,
    'resolved': 0,
    'rejected': 0,
  };

  @override
  void initState() {
    super.initState();
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
      String endpoint = ApiConstants.adminComplaints;
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
        final statistics =
            response['data']?['statistics'] as Map<String, dynamic>?;

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

            // Calculate statistics from complaints if API doesn't provide them
            if (statistics != null) {
              _statistics = {
                'total': (statistics['total'] as num?)?.toInt() ?? 0,
                'open': (statistics['open'] as num?)?.toInt() ?? 0,
                'inProgress': (statistics['inProgress'] as num?)?.toInt() ?? 0,
                'resolved': (statistics['resolved'] as num?)?.toInt() ?? 0,
                'rejected': (statistics['rejected'] as num?)?.toInt() ?? 0,
              };
            } else {
              _calculateStatistics();
            }
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

  void _calculateStatistics() {
    int total = _complaints.length;
    int open = 0;
    int inProgress = 0;
    int resolved = 0;
    int rejected = 0;

    for (var complaint in _complaints) {
      final status = (complaint['status']?.toString() ?? '').toLowerCase();
      if (status == 'open') {
        open++;
      } else if (status == 'in progress' || status == 'assigned') {
        inProgress++;
      } else if (status == 'resolved' || status == 'closed') {
        resolved++;
      } else if (status == 'rejected' || status == 'cancelled') {
        rejected++;
      }
    }

    _statistics = {
      'total': total,
      'open': open,
      'inProgress': inProgress,
      'resolved': resolved,
      'rejected': rejected,
    };
  }

  void _applyFilters() {
    setState(() {
      _filteredComplaints = _complaints.where((complaint) {
        // Building filter
        if (_selectedBuildingFilter != 'all') {
          final createdBy = complaint['createdBy'] ?? {};
          final apartmentCode = createdBy['apartmentCode']?.toString();
          if (apartmentCode != _selectedBuildingFilter) {
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
        // Wing filter
        if (_selectedWing != 'all') {
          final createdBy = complaint['createdBy'] ?? {};
          if (createdBy['wing'] != _selectedWing) {
            return false;
          }
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
      _selectedWing = 'all';
      _selectedBuildingFilter = 'all';
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
    if (_selectedWing != 'all') count++;
    if (_selectedBuildingFilter != 'all') count++;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Complaints Management'),
            if (_statistics['total'] != null)
              Text(
                '${_statistics['total']} Total • ${_statistics['open'] ?? 0} Open • ${_statistics['inProgress'] ?? 0} In Progress',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
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
              margin: const EdgeInsets.only(right: 8),
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
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
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
      body: Column(
        children: [
          // Key Statistics Section - Modern Premium Design
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Key Statistics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Statistics Grid
                Row(
                  children: [
                    Expanded(
                      child: _ModernStatCard(
                        title: 'Total',
                        value: _statistics['total'] ?? 0,
                        icon: Icons.description_outlined,
                        color: AppColors.info,
                        gradient: [
                          AppColors.info.withOpacity(0.1),
                          AppColors.info.withOpacity(0.05),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModernStatCard(
                        title: 'Open',
                        value: _statistics['open'] ?? 0,
                        icon: Icons.pending_actions,
                        color: AppColors.error,
                        gradient: [
                          AppColors.error.withOpacity(0.1),
                          AppColors.error.withOpacity(0.05),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModernStatCard(
                        title: 'In Progress',
                        value: _statistics['inProgress'] ?? 0,
                        icon: Icons.sync,
                        color: AppColors.warning,
                        gradient: [
                          AppColors.warning.withOpacity(0.1),
                          AppColors.warning.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ModernStatCard(
                        title: 'Resolved',
                        value: _statistics['resolved'] ?? 0,
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        gradient: [
                          AppColors.success.withOpacity(0.1),
                          AppColors.success.withOpacity(0.05),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModernStatCard(
                        title: 'Rejected',
                        value: _statistics['rejected'] ?? 0,
                        icon: Icons.cancel_outlined,
                        color: Colors.grey,
                        gradient: [
                          Colors.grey.withOpacity(0.1),
                          Colors.grey.withOpacity(0.05),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Empty space for alignment
                    Expanded(child: Container()),
                  ],
                ),
              ],
            ),
          ),

          // Filters Section - Enhanced with smooth animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showFilters ? null : 0,
            child: _showFilters
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.tune,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Filters',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (activeFilterCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$activeFilterCount active',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Clear All'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Enhanced Search Bar
                        TextField(
                          controller: _searchController
                            ..text = _searchQuery
                            ..selection = TextSelection.collapsed(
                              offset: _searchQuery.length,
                            ),
                          decoration: InputDecoration(
                            hintText:
                                'Search by title, ticket number, or resident name...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _applyFilters();
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
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
                        const SizedBox(height: 16),
                        // Filter Chips Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_getUniqueBuildingCodes().isNotEmpty)
                              _FilterChip(
                                label: 'Building',
                                value: _selectedBuildingFilter,
                                options: ['all', ..._getUniqueBuildingCodes()],
                                getDisplayName: (code) {
                                  if (code == 'all') return 'All';
                                  final building = _allBuildings.firstWhere(
                                    (b) => b['code'] == code,
                                    orElse: () => {'name': code},
                                  );
                                  return building['name']?.toString() ?? code;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBuildingFilter = value;
                                    _applyFilters();
                                  });
                                },
                              ),
                            _FilterChip(
                              label: 'Status',
                              value: _selectedStatus,
                              options: const [
                                'all',
                                'Open',
                                'Assigned',
                                'In Progress',
                                'Resolved',
                                'Closed',
                                'Cancelled',
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                  _applyFilters();
                                });
                              },
                            ),
                            _FilterChip(
                              label: 'Category',
                              value: _selectedCategory,
                              options: const [
                                'all',
                                'Electrical',
                                'Plumbing',
                                'Carpentry',
                                'Cleaning',
                                'Security',
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  _applyFilters();
                                });
                              },
                            ),
                            _FilterChip(
                              label: 'Priority',
                              value: _selectedPriority,
                              options: const [
                                'all',
                                'Emergency',
                                'High',
                                'Medium',
                                'Low',
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedPriority = value;
                                  _applyFilters();
                                });
                              },
                            ),
                            if (_getUniqueWings().isNotEmpty)
                              _FilterChip(
                                label: 'Wing',
                                value: _selectedWing,
                                options: ['all', ..._getUniqueWings()],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedWing = value;
                                    _applyFilters();
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Date Range Picker
                        InkWell(
                          onTap: _selectDateRange,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: (_startDate != null || _endDate != null)
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: (_startDate != null || _endDate != null)
                                    ? 2
                                    : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: (_startDate != null || _endDate != null)
                                  ? AppColors.primary.withOpacity(0.05)
                                  : AppColors.background,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color:
                                      (_startDate != null || _endDate != null)
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _startDate != null && _endDate != null
                                        ? '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                                        : 'Select Date Range',
                                    style: TextStyle(
                                      color:
                                          (_startDate != null ||
                                              _endDate != null)
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontWeight:
                                          (_startDate != null ||
                                              _endDate != null)
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (_startDate != null || _endDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _startDate = null;
                                        _endDate = null;
                                        _applyFilters();
                                      });
                                    },
                                    color: AppColors.textSecondary,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Complaints List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredComplaints.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No complaints found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_selectedStatus != 'all' ||
                            _selectedCategory != 'all' ||
                            _selectedPriority != 'all' ||
                            _selectedWing != 'all' ||
                            _startDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            ),
                          ),
                      ],
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
                            ? DateTime.parse(complaint['createdAt'].toString())
                            : null;
                        final updatedAt = complaint['updatedAt'] != null
                            ? DateTime.parse(complaint['updatedAt'].toString())
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

class _ModernStatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  State<_ModernStatCard> createState() => _ModernStatCardState();
}

class _ModernStatCardState extends State<_ModernStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradient,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.color.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.value.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
