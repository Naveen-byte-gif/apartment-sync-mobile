import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'create_user_screen.dart';
import '../complaints/resident_complaints_screen.dart';
import '../payments/payments_screen.dart';
import '../../widgets/app_sidebar.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class BulkResidentManagementScreen extends StatefulWidget {
  const BulkResidentManagementScreen({super.key});

  @override
  State<BulkResidentManagementScreen> createState() =>
      _BulkResidentManagementScreenState();
}

class _BulkResidentManagementScreenState
    extends State<BulkResidentManagementScreen> {
  List<Map<String, dynamic>> _residents = [];
  List<Map<String, dynamic>> _filteredResidents = [];
  Set<String> _selectedResidentIds = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  String _searchQuery = '';
  Map<String, dynamic>? _statistics;
  String? _selectedBuildingCode;
  List<Map<String, dynamic>> _allBuildings = [];

  // Filters
  String? _filterStatus;
  String? _filterFloor;
  String? _filterPaymentStatus;
  String? _filterComplaintStatus;
  String? _filterVerificationStatus;
  String? _filterRiskLevel;
  bool _showFilters = false;

  int _currentPage = 1;
  int _totalPages = 1;
  final int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userId = userData['_id'] ?? userData['id'];
        if (userId != null) {
          socketService.connect(userId);
          socketService.on('user_created', (_) => _loadResidents());
          socketService.on('user_updated', (_) => _loadResidents());
          socketService.on('bulk_resident_action', (_) => _loadResidents());
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
          if (_allBuildings.isNotEmpty && _selectedBuildingCode == null) {
            _selectedBuildingCode =
                StorageService.getString(AppConstants.selectedBuildingKey) ??
                _allBuildings.first['code'];
          }
        });
        _loadResidents();
      }
    } catch (e) {
      print('❌ [FLUTTER] Error loading buildings: $e');
      _loadResidents();
    }
  }

  Future<void> _loadResidents({bool resetPage = false}) async {
    if (resetPage) _currentPage = 1;

    setState(() => _isLoading = true);
    try {
      String endpoint = ApiConstants.adminResidents;
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': _pageSize.toString(),
      };

      if (_selectedBuildingCode != null) {
        queryParams['buildingCode'] = _selectedBuildingCode!;
      }
      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }
      if (_filterStatus != null) {
        queryParams['status'] = _filterStatus!;
      }
      if (_filterFloor != null) {
        queryParams['floor'] = _filterFloor!;
      }
      if (_filterPaymentStatus != null) {
        queryParams['paymentStatus'] = _filterPaymentStatus!;
      }
      if (_filterComplaintStatus != null) {
        queryParams['complaintStatus'] = _filterComplaintStatus!;
      }
      if (_filterVerificationStatus != null) {
        queryParams['verificationStatus'] = _filterVerificationStatus!;
      }
      if (_filterRiskLevel != null) {
        queryParams['riskLevel'] = _filterRiskLevel!;
      }

      // Build query string
      final queryString = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final fullEndpoint = queryString.isNotEmpty
          ? '$endpoint?$queryString'
          : endpoint;

      final response = await ApiService.get(fullEndpoint);

      if (response['success'] == true) {
        setState(() {
          _residents = List<Map<String, dynamic>>.from(
            response['data']?['residents'] ?? [],
          );
          _statistics = response['data']?['statistics'];
          _totalPages = response['data']?['pagination']?['pages'] ?? 1;
          _applyFilters();
        });
      } else {
        AppMessageHandler.showError(
          context,
          response['message'] ?? 'Failed to load residents',
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredResidents = List.from(_residents);
    });
  }

  void _toggleSelection(String residentId) {
    setState(() {
      if (_selectedResidentIds.contains(residentId)) {
        _selectedResidentIds.remove(residentId);
      } else {
        _selectedResidentIds.add(residentId);
      }
      if (_selectedResidentIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  String _getResidentId(Map<String, dynamic> resident) {
    return (resident['_id'] ?? resident['id']).toString();
  }

  void _selectAll() {
    setState(() {
      if (_selectedResidentIds.length == _filteredResidents.length) {
        _selectedResidentIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedResidentIds = _filteredResidents
            .map((r) => (r['_id'] ?? r['id']).toString())
            .toSet()
            .cast<String>();
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _performBulkAction(String action, {String? reason}) async {
    if (_selectedResidentIds.isEmpty) {
      AppMessageHandler.showError(
        context,
        'Please select at least one resident',
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Bulk Action'),
        content: Text(
          'Are you sure you want to ${action} ${_selectedResidentIds.length} resident(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show reason dialog if needed
    if (action == 'reject' || action == 'suspend') {
      final reasonController = TextEditingController();
      final reasonResult = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reason for ${action}'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reasonController.text),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      reason = reasonResult;
    }

    try {
      final response =
          await ApiService.post(ApiConstants.adminResidentsBulkAction, {
            'action': action,
            'residentIds': _selectedResidentIds.toList(),
            'reason': reason,
          });

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          '${response['data']?['succeeded'] ?? 0} resident(s) ${action}ed successfully',
        );
        setState(() {
          _selectedResidentIds.clear();
          _isSelectionMode = false;
        });
        _loadResidents();
      } else {
        AppMessageHandler.showError(
          context,
          response['message'] ?? 'Action failed',
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get building name for sidebar
    final buildingName = _selectedBuildingCode != null && _allBuildings.isNotEmpty
        ? _allBuildings.firstWhere(
            (b) => b['code'] == _selectedBuildingCode,
            orElse: () => {'name': ''},
          )['name'] ?? ''
        : null;

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
            StorageService.setString(
              AppConstants.selectedBuildingKey,
              code,
            );
          });
          _loadResidents(resetPage: true);
        },
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resident Management'),
            if (_statistics != null)
              Text(
                '${_statistics!['total'] ?? 0} Total • ${_statistics!['pending'] ?? 0} Pending • ${_statistics!['highRisk'] ?? 0} High Risk',
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
          if (_allBuildings.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.apartment),
              onSelected: (code) {
                setState(() {
                  _selectedBuildingCode = code;
                  StorageService.setString(
                    AppConstants.selectedBuildingKey,
                    code,
                  );
                });
                _loadResidents(resetPage: true);
              },
              itemBuilder: (context) =>
                  _allBuildings.map<PopupMenuEntry<String>>((building) {
                    return PopupMenuItem<String>(
                      value: building['code']?.toString() ?? '',
                      child: Row(
                        children: [
                          if (_selectedBuildingCode == building['code'])
                            const Icon(
                              Icons.check,
                              color: AppColors.primary,
                              size: 16,
                            )
                          else
                            const SizedBox(width: 16),
                          Text(building['name'] ?? building['code'] ?? ''),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateUserScreen()),
              ).then((_) => _loadResidents());
            },
            tooltip: 'Add Resident',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadResidents(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          if (_statistics != null) _buildStatisticsBar(),
          // Search Bar
          _buildSearchBar(),
          // Filters
          if (_showFilters) _buildFilters(),
          // Bulk Action Toolbar
          if (_isSelectionMode && _selectedResidentIds.isNotEmpty)
            _buildBulkActionToolbar(),
          // Residents List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredResidents.isEmpty
                ? _buildEmptyState()
                : _buildResidentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Total',
              value: '${_statistics!['total'] ?? 0}',
              color: AppColors.primary,
              icon: Icons.people,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Pending',
              value: '${_statistics!['pending'] ?? 0}',
              color: AppColors.warning,
              icon: Icons.pending,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Active',
              value: '${_statistics!['active'] ?? 0}',
              color: AppColors.success,
              icon: Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'High Risk',
              value: '${_statistics!['highRisk'] ?? 0}',
              color: AppColors.error,
              icon: Icons.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, flat, phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _loadResidents(resetPage: true);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                if (value.isEmpty) {
                  _loadResidents(resetPage: true);
                }
              },
              onSubmitted: (_) => _loadResidents(resetPage: true),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              _isSelectionMode
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) {
                  _selectedResidentIds.clear();
                }
              });
            },
            tooltip: 'Selection Mode',
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterStatus = null;
                    _filterFloor = null;
                    _filterPaymentStatus = null;
                    _filterComplaintStatus = null;
                    _filterVerificationStatus = null;
                    _filterRiskLevel = null;
                  });
                  _loadResidents(resetPage: true);
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Status',
                value: _filterStatus,
                options: ['all', 'pending', 'active', 'suspended'],
                onChanged: (value) {
                  setState(() => _filterStatus = value == 'all' ? null : value);
                  _loadResidents(resetPage: true);
                },
              ),
              _FilterChip(
                label: 'Risk Level',
                value: _filterRiskLevel,
                options: ['all', 'low', 'medium', 'high'],
                onChanged: (value) {
                  setState(
                    () => _filterRiskLevel = value == 'all' ? null : value,
                  );
                  _loadResidents(resetPage: true);
                },
              ),
              _FilterChip(
                label: 'Complaints',
                value: _filterComplaintStatus,
                options: ['all', 'active'],
                onChanged: (value) {
                  setState(
                    () =>
                        _filterComplaintStatus = value == 'all' ? null : value,
                  );
                  _loadResidents(resetPage: true);
                },
              ),
              _FilterChip(
                label: 'Verification',
                value: _filterVerificationStatus,
                options: ['all', 'pending', 'approved', 'rejected'],
                onChanged: (value) {
                  setState(
                    () => _filterVerificationStatus = value == 'all'
                        ? null
                        : value,
                  );
                  _loadResidents(resetPage: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primary,
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _selectAll,
            icon: const Icon(Icons.select_all, color: Colors.white),
            label: Text(
              _selectedResidentIds.length == _filteredResidents.length
                  ? 'Deselect All'
                  : 'Select All',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedResidentIds.length} selected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.surface,
            onSelected: (action) => _performBulkAction(action),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Approve'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Reject'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'suspend',
                child: Row(
                  children: [
                    Icon(Icons.block, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text('Suspend'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'activate',
                child: Row(
                  children: [
                    Icon(Icons.play_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Activate'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'send_reminder',
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: AppColors.info),
                    SizedBox(width: 8),
                    Text('Send Reminder'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedResidentIds.clear();
                _isSelectionMode = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResidentsList() {
    return RefreshIndicator(
      onRefresh: () => _loadResidents(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredResidents.length + (_totalPages > 1 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredResidents.length) {
            return _buildPagination();
          }
          final resident = _filteredResidents[index];
          final residentId = _getResidentId(resident);
          return _ResidentCard(
            resident: resident,
            isSelected:
                _isSelectionMode && _selectedResidentIds.contains(residentId),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(residentId);
              } else {
                _showResidentActions(context, resident);
              }
            },
            onLongPress: () {
              setState(() => _isSelectionMode = true);
              _toggleSelection(residentId);
            },
            onSwipeRight: () => _handleQuickAction(resident, 'message'),
            onSwipeLeft: () => _handleQuickAction(resident, 'dues'),
          );
        },
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadResidents();
                  }
                : null,
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadResidents();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Residents Found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or add a new resident',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showResidentActions(
    BuildContext context,
    Map<String, dynamic> resident,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ResidentActionSheet(
        resident: resident,
        onViewDetails: () {
          Navigator.pop(context);
          _navigateToResidentDetails(resident);
        },
        onSendMessage: () {
          Navigator.pop(context);
          _navigateToSendMessage(resident);
        },
        onViewDues: () {
          Navigator.pop(context);
          _navigateToViewDues(resident);
        },
        onViewComplaints: () {
          Navigator.pop(context);
          _navigateToViewComplaints(resident);
        },
        onStatusChanged: () {
          _loadResidents();
        },
      ),
    );
  }

  void _handleQuickAction(Map<String, dynamic> resident, String action) {
    HapticFeedback.lightImpact();
    switch (action) {
      case 'message':
        _navigateToSendMessage(resident);
        break;
      case 'dues':
        _navigateToViewDues(resident);
        break;
    }
  }

  void _navigateToResidentDetails(Map<String, dynamic> resident) {
    // Create a resident details screen or navigate to profile view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ResidentDetailsScreen(resident: resident),
      ),
    );
  }

  void _navigateToSendMessage(Map<String, dynamic> resident) async {
    final residentId = _getResidentId(resident);
    final residentName = resident['fullName'] ?? 'Resident';
    final residentPhone = resident['phoneNumber'] ?? '';

    // Show message options (SMS)
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MessageOptionsSheet(
        residentName: residentName,
        residentPhone: residentPhone,
        residentId: residentId,
        onSendSMS: () async {
          Navigator.pop(context);
          final uri = Uri.parse('sms:$residentPhone');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else if (context.mounted) {
            AppMessageHandler.showError(context, 'Cannot open SMS app');
          }
        },
      ),
    );
  }

  void _navigateToViewDues(Map<String, dynamic> resident) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentsScreen()),
    );
  }

  void _navigateToViewComplaints(Map<String, dynamic> resident) {
    final residentId = _getResidentId(resident);
    final residentName = resident['fullName'] ?? 'Resident';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResidentComplaintsScreen(
          residentId: residentId,
          residentName: residentName,
        ),
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final Function(String) onChanged;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: value != null
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${value ?? "All"}',
              style: TextStyle(
                color: value != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: value != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => options.map((option) {
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              if (value == option)
                const Icon(Icons.check, color: AppColors.primary, size: 16)
              else
                const SizedBox(width: 16),
              Text(option.toUpperCase()),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Resident Card Widget
class _ResidentCard extends StatelessWidget {
  final Map<String, dynamic> resident;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;

  const _ResidentCard({
    required this.resident,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.onSwipeRight,
    this.onSwipeLeft,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'suspended':
        return AppColors.error;
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = resident['status'] ?? 'pending';
    final riskLevel = resident['riskLevel'] ?? 'low';
    final hasComplaints = resident['hasActiveComplaints'] == true;
    final complaintsCount = resident['complaintsCount'] ?? 0;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 1000 && onSwipeRight != null) {
            onSwipeRight!();
          } else if (details.primaryVelocity! < -1000 && onSwipeLeft != null) {
            onSwipeLeft!();
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isSelected ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Checkbox
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      shape: BoxShape.circle,
                    ),
                  ),
                // Avatar with status indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _getStatusColor(status).withOpacity(0.1),
                      child: Text(
                        (resident['fullName'] ?? 'N')[0].toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              resident['fullName'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Risk Badge
                          if (riskLevel != 'low')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getRiskColor(
                                  riskLevel,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                riskLevel.toUpperCase(),
                                style: TextStyle(
                                  color: _getRiskColor(riskLevel),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.home,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Floor ${resident['floorNumber'] ?? 'N/A'} • Flat ${resident['flatNumber'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.phone,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              resident['phoneNumber'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'active'
                                      ? Icons.check_circle
                                      : status == 'pending'
                                      ? Icons.pending
                                      : status == 'suspended'
                                      ? Icons.block
                                      : Icons.cancel,
                                  size: 12,
                                  color: _getStatusColor(status),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasComplaints)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning,
                                    size: 12,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$complaintsCount Complaint${complaintsCount > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (resident['paymentStatus'] == 'overdue' ||
                              resident['hasPendingDues'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.payment,
                                    size: 12,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DUE',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
                // Actions
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_vert,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ), // Closes Card (child of GestureDetector)
    ); // Closes GestureDetector
  }
}

// Resident Action Sheet (Bottom Sheet)
class _ResidentActionSheet extends StatefulWidget {
  final Map<String, dynamic> resident;
  final VoidCallback onViewDetails;
  final VoidCallback onSendMessage;
  final VoidCallback onViewDues;
  final VoidCallback onViewComplaints;
  final VoidCallback? onStatusChanged;

  const _ResidentActionSheet({
    required this.resident,
    required this.onViewDetails,
    required this.onSendMessage,
    required this.onViewDues,
    required this.onViewComplaints,
    this.onStatusChanged,
  });

  @override
  State<_ResidentActionSheet> createState() => _ResidentActionSheetState();
}

class _ResidentActionSheetState extends State<_ResidentActionSheet> {
  bool _isUpdatingStatus = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'suspended':
        return AppColors.error;
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'suspended':
        return Icons.block;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final oldStatus = widget.resident['status'] ?? 'pending';
    
    // Show confirmation dialog for critical status changes
    if (newStatus == 'suspended' || newStatus == 'rejected') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Change Status to ${newStatus.toUpperCase()}?'),
          content: Text(
            newStatus == 'suspended'
                ? 'Are you sure you want to suspend this resident? They will lose access to the app.'
                : 'Are you sure you want to reject this resident? This action cannot be easily undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isUpdatingStatus = true);
    try {
      final residentId = (widget.resident['_id'] ?? widget.resident['id']).toString();
      
      // Use bulk action endpoint for single resident
      final response = await ApiService.post(
        ApiConstants.adminResidentsBulkAction,
        {
          'action': newStatus == 'active' ? 'approve' : 
                    newStatus == 'rejected' ? 'reject' :
                    newStatus == 'suspended' ? 'suspend' : 'activate',
          'residentIds': [residentId],
          'reason': 'Status changed from $oldStatus to $newStatus',
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          AppMessageHandler.showSuccess(
            context,
            'Status updated to ${newStatus.toUpperCase()}',
          );
          Navigator.pop(context);
          if (widget.onStatusChanged != null) {
            widget.onStatusChanged!();
          }
        }
      } else {
        if (mounted) {
          AppMessageHandler.showError(
            context,
            response['message'] ?? 'Failed to update status',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasComplaints = widget.resident['hasActiveComplaints'] == true;
    final complaintsCount = widget.resident['complaintsCount'] ?? 0;
    final hasPendingDues =
        widget.resident['hasPendingDues'] == true ||
        widget.resident['paymentStatus'] == 'overdue';
    final currentStatus = widget.resident['status'] ?? 'pending';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      (widget.resident['fullName'] ?? 'N')[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.resident['fullName'] ?? 'Resident',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Floor ${widget.resident['floorNumber'] ?? 'N/A'} • Flat ${widget.resident['flatNumber'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Status Change Section (Similar to Complaints)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status & Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Dropdown (Same style as Complaints)
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: currentStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    items: ['pending', 'active', 'suspended', 'rejected']
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Icon(
                                    _getStatusIcon(s),
                                    size: 18,
                                    color: _getStatusColor(s),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.toUpperCase()),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: _isUpdatingStatus
                        ? null
                        : (newStatus) {
                            if (newStatus != null && newStatus != currentStatus) {
                              _updateStatus(newStatus);
                            }
                          },
                  ),
                  if (_isUpdatingStatus)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // View Details (Primary Action)
                  _ActionItem(
                    icon: Icons.person,
                    iconColor: AppColors.info,
                    title: 'View Details',
                    description:
                        'View full resident profile, flat info, payments, and history',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onViewDetails();
                    },
                    isPrimary: true,
                  ),
                  // Send Message
                  _ActionItem(
                    icon: Icons.message,
                    iconColor: AppColors.success,
                    title: 'Send Message',
                    description: 'Send SMS or in-app message instantly',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onSendMessage();
                    },
                  ),
                  // View Dues
                  _ActionItem(
                    icon: Icons.account_balance_wallet,
                    iconColor: AppColors.warning,
                    title: 'View Dues',
                    description: hasPendingDues
                        ? 'Check pending maintenance and payment history'
                        : 'View payment history',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onViewDues();
                    },
                    badge: hasPendingDues ? 'DUE' : null,
                  ),
                  // View Complaints
                  _ActionItem(
                    icon: Icons.build,
                    iconColor: AppColors.error,
                    title: 'View Complaints',
                    description: hasComplaints
                        ? 'View active and past complaints with status'
                        : 'View complaint history',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onViewComplaints();
                    },
                    badge: hasComplaints ? '$complaintsCount Active' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Action Item Widget
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isPrimary;
  final String? badge;

  const _ActionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
    this.isPrimary = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isPrimary
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// Message Options Sheet
class _MessageOptionsSheet extends StatelessWidget {
  final String residentName;
  final String residentPhone;
  final String residentId;
  final VoidCallback onSendSMS;

  const _MessageOptionsSheet({
    required this.residentName,
    required this.residentPhone,
    required this.residentId,
    required this.onSendSMS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Send Message to $residentName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _MessageOption(
                icon: Icons.sms,
                iconColor: AppColors.info,
                title: 'Send SMS',
                description: 'Open SMS app to send text message',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSendSMS();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// Message Option Widget
class _MessageOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _MessageOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// Resident Details Screen
class _ResidentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> resident;

  const _ResidentDetailsScreen({required this.resident});

  @override
  State<_ResidentDetailsScreen> createState() => _ResidentDetailsScreenState();
}

class _ResidentDetailsScreenState extends State<_ResidentDetailsScreen> {
  Map<String, dynamic>? _residentDetails;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadResidentDetails();
  }

  Future<void> _loadResidentDetails() async {
    setState(() => _isLoading = true);
    try {
      // Load full resident details from API
      final response = await ApiService.get(
        '${ApiConstants.adminUsers}?id=${widget.resident['_id'] ?? widget.resident['id']}',
      );
      if (response['success'] == true) {
        final users = response['data']?['users'] ?? [];
        if (users.isNotEmpty) {
          setState(() {
            _residentDetails = users.first;
          });
        }
      }
    } catch (e) {
      print('Error loading resident details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resident = _residentDetails ?? widget.resident;
    final status = resident['status'] ?? 'pending';
    final riskLevel = resident['riskLevel'] ?? 'low';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resident Details'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  _buildProfileHeader(resident, status, riskLevel),
                  const SizedBox(height: 24),
                  // Personal Information
                  _buildSection(
                    title: 'Personal Information',
                    children: [
                      _InfoRow(
                        label: 'Full Name',
                        value: resident['fullName'] ?? 'N/A',
                      ),
                      _InfoRow(
                        label: 'Phone',
                        value: resident['phoneNumber'] ?? 'N/A',
                      ),
                      if (resident['email'] != null)
                        _InfoRow(label: 'Email', value: resident['email']),
                      _InfoRow(
                        label: 'Status',
                        value: status.toUpperCase(),
                        valueColor: _getStatusColor(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Flat Information
                  _buildSection(
                    title: 'Flat Information',
                    children: [
                      _InfoRow(
                        label: 'Floor',
                        value: '${resident['floorNumber'] ?? 'N/A'}',
                      ),
                      _InfoRow(
                        label: 'Flat Number',
                        value: resident['flatNumber'] ?? 'N/A',
                      ),
                      _InfoRow(
                        label: 'Flat Type',
                        value: resident['flatType'] ?? 'N/A',
                      ),
                      if (resident['wing'] != null)
                        _InfoRow(label: 'Wing', value: resident['wing']),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Status Change Section (Same as Complaints)
                  _buildStatusChangeSection(resident, status),
                  const SizedBox(height: 24),
                  // Risk & Status
                  _buildSection(
                    title: 'Risk & Status',
                    children: [
                      _InfoRow(
                        label: 'Risk Level',
                        value: riskLevel.toUpperCase(),
                        valueColor: _getRiskColor(riskLevel),
                      ),
                      if (resident['complaintsCount'] != null)
                        _InfoRow(
                          label: 'Active Complaints',
                          value: '${resident['complaintsCount']}',
                          valueColor: resident['complaintsCount'] > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      _InfoRow(
                        label: 'Registered At',
                        value: resident['registeredAt'] != null
                            ? DateTime.parse(
                                resident['registeredAt'],
                              ).toString().split(' ')[0]
                            : 'N/A',
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(
    Map<String, dynamic> resident,
    String status,
    String riskLevel,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _getStatusColor(status),
            child: Text(
              (resident['fullName'] ?? 'N')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resident['fullName'] ?? 'Resident',
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
                        color: _getStatusColor(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (riskLevel != 'low') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getRiskColor(riskLevel).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${riskLevel.toUpperCase()} RISK',
                          style: TextStyle(
                            color: _getRiskColor(riskLevel),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'suspended':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'suspended':
        return Icons.block;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStatusChangeSection(Map<String, dynamic> resident, String currentStatus) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Status & Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Status Dropdown (Same style as Complaints)
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currentStatus,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            items: ['pending', 'active', 'suspended', 'rejected']
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(s),
                            size: 18,
                            color: _getStatusColor(s),
                          ),
                          const SizedBox(width: 8),
                          Text(s.toUpperCase()),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: _isUpdatingStatus
                ? null
                : (newStatus) {
                    if (newStatus != null && newStatus != currentStatus) {
                      _updateStatus(newStatus, resident);
                    }
                  },
          ),
          if (_isUpdatingStatus)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus, Map<String, dynamic> resident) async {
    final oldStatus = resident['status'] ?? 'pending';
    
    // Show confirmation dialog for critical status changes
    if (newStatus == 'suspended' || newStatus == 'rejected') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Change Status to ${newStatus.toUpperCase()}?'),
          content: Text(
            newStatus == 'suspended'
                ? 'Are you sure you want to suspend this resident? They will lose access to the app.'
                : 'Are you sure you want to reject this resident? This action cannot be easily undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isUpdatingStatus = true);
    try {
      final residentId = (resident['_id'] ?? resident['id']).toString();
      
      // Use bulk action endpoint for single resident
      final response = await ApiService.post(
        ApiConstants.adminResidentsBulkAction,
        {
          'action': newStatus == 'active' ? 'approve' : 
                    newStatus == 'rejected' ? 'reject' :
                    newStatus == 'suspended' ? 'suspend' : 'activate',
          'residentIds': [residentId],
          'reason': 'Status changed from $oldStatus to $newStatus',
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          AppMessageHandler.showSuccess(
            context,
            'Status updated to ${newStatus.toUpperCase()}',
          );
          // Reload resident details
          await _loadResidentDetails();
        }
      } else {
        if (mounted) {
          AppMessageHandler.showError(
            context,
            response['message'] ?? 'Failed to update status',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
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
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
