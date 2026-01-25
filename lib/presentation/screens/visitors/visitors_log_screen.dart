import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/visitor_export_service.dart';
import '../../../core/services/visitor_filter_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';
import 'new_visitor_entry_screen.dart';
import 'visitor_detail_screen.dart';
import 'visitor_dashboard_screen.dart';

class VisitorsLogScreen extends StatefulWidget {
  const VisitorsLogScreen({super.key});

  @override
  State<VisitorsLogScreen> createState() => _VisitorsLogScreenState();
}

class _VisitorsLogScreenState extends State<VisitorsLogScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _visitors = [];
  List<Map<String, dynamic>> _filteredVisitors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Map<String, dynamic>? _user;
  int _currentIndex = 1; // 0 = Dashboard, 1 = Visitor Log
  
  // Keep alive to preserve state
  @override
  bool get wantKeepAlive => true;

  // Advanced Filters
  String? _selectedStatus;
  String? _selectedBuilding;
  String? _selectedVisitorType;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _availableBuildings = [];
  List<String> _availableVisitorTypes = [
    'All',
    'Guest',
    'Delivery',
    'Vendor',
    'Cab / Ride',
    'Domestic Help',
    'Realtor / Sales',
    'Emergency Services',
  ];
  List<String> _availableStatuses = [
    'All',
    'Pending',
    'Pre-Approved',
    'Checked In',
    'Checked Out',
    'Rejected',
    'Cancelled',
  ];

  // Constants for filter values
  static const String _allFilterValue = 'All';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAvailableBuildings();
    _loadVisitors();
    _setupSocketListeners();
  }

  void _loadUserData() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        setState(() {
          _user = jsonDecode(userJson);
        });
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
  }

  void _loadAvailableBuildings() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        final userRole = userData['role'] ?? 'resident';

        if (userRole == 'resident') {
          // For residents, don't show building filter - they only see their flat visitors
          setState(() {
            _availableBuildings = [];
            _selectedBuilding = null;
          });
        } else {
          setState(() {
            _availableBuildings = [_allFilterValue];
            _selectedBuilding = _allFilterValue;
          });
        }
      } catch (e) {
        print('Error loading buildings: $e');
      }
    }
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

          // Remove old listeners to prevent duplicates
          socketService.off('visitor_created');
          socketService.off('visitor_checked_in');
          socketService.off('visitor_checked_out');
          socketService.off('visitor_status_updated');

          socketService.on('visitor_created', (data) {
            print('🔔 [SOCKET] Visitor created event received');
            if (mounted) {
              _loadVisitors();
            }
          });

          socketService.on('visitor_checked_in', (data) {
            print('🔔 [SOCKET] Visitor checked in event received');
            if (mounted) {
              _loadVisitors();
            }
          });

          socketService.on('visitor_checked_out', (data) {
            print('🔔 [SOCKET] Visitor checked out event received');
            if (mounted) {
              _loadVisitors();
            }
          });

          socketService.on('visitor_status_updated', (data) {
            print('🔔 [SOCKET] Visitor status updated event received');
            if (mounted) {
              _loadVisitors();
            }
          });
        }
      } catch (e) {
        print('Error setting up socket: $e');
      }
    }
  }

  @override
  void dispose() {
    // Clean up socket listeners
    final socketService = SocketService();
    socketService.off('visitor_created');
    socketService.off('visitor_checked_in');
    socketService.off('visitor_checked_out');
    socketService.off('visitor_status_updated');
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      // Build query with filters
      String url = ApiConstants.visitors;
      List<String> queryParams = [];

      if (_selectedStatus != null && _selectedStatus != 'All') {
        queryParams.add('status=${Uri.encodeComponent(_selectedStatus!)}');
      }
      if (_selectedBuilding != null && _selectedBuilding != 'All') {
        queryParams.add('building=${Uri.encodeComponent(_selectedBuilding!)}');
      }
      if (_startDate != null) {
        queryParams.add('startDate=${_startDate!.toIso8601String()}');
      }
      if (_endDate != null) {
        queryParams.add('endDate=${_endDate!.toIso8601String()}');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await ApiService.get(url);
      if (response['success'] == true) {
        setState(() {
          _visitors = List<Map<String, dynamic>>.from(
            response['data']?['visitors'] ?? [],
          );
          _applyFilters();
        });
      } else {
        AppMessageHandler.handleResponse(context, response);
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
      _filteredVisitors = VisitorFilterService.applyFilters(
        visitors: _visitors,
        status: _selectedStatus == _allFilterValue ? null : _selectedStatus,
        building: _selectedBuilding == _allFilterValue ? null : _selectedBuilding,
        visitorType: _selectedVisitorType == _allFilterValue ? null : _selectedVisitorType,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = _allFilterValue;
      _selectedBuilding = _allFilterValue;
      _selectedVisitorType = _allFilterValue;
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
    });
    _applyFilters();
    _loadVisitors();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textOnPrimary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  Future<void> _exportToExcel({String? exportType}) async {
    try {
      final filePath = await VisitorExportService.exportToExcel(
        visitors: _filteredVisitors,
        startDate: _startDate,
        endDate: _endDate,
        exportType: exportType,
      );

      if (filePath != null && mounted) {
        AppMessageHandler.showSuccess(
          context,
          'Excel file exported successfully',
        );
        await VisitorExportService.shareFile(filePath, 'Excel');
      } else if (mounted) {
        AppMessageHandler.showError(context, 'Failed to export Excel file');
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.showError(context, 'Error exporting to Excel: $e');
      }
    }
  }

  Future<void> _exportToPDF({String? exportType}) async {
    try {
      final filePath = await VisitorExportService.exportToPDF(
        visitors: _filteredVisitors,
        startDate: _startDate,
        endDate: _endDate,
        exportType: exportType,
      );

      if (filePath != null && mounted) {
        AppMessageHandler.showSuccess(
          context,
          'PDF file exported successfully',
        );
        await VisitorExportService.shareFile(filePath, 'PDF');
      } else if (mounted) {
        AppMessageHandler.showError(context, 'Failed to export PDF file');
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.showError(context, 'Error exporting to PDF: $e');
      }
    }
  }

  Future<void> _showExportDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Export Options',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildExportOption(
              icon: Icons.date_range,
              title: 'Date Range Export',
              subtitle: _startDate != null && _endDate != null
                  ? VisitorFilterService.formatDateRange(_startDate, _endDate)
                  : 'Export filtered data by date range',
              onTap: () {
                Navigator.pop(context);
                _showExportFormatDialog('date_range');
              },
            ),
            const SizedBox(height: 12),
            _buildExportOption(
              icon: Icons.calendar_month,
              title: 'Month-wise Export',
              subtitle: 'Export data for a specific month',
              onTap: () {
                Navigator.pop(context);
                _showMonthSelectionDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportFormatDialog(String exportType) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Select Format',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.table_chart, color: AppColors.primary),
              title: Text('Excel (.xlsx)'),
              subtitle: Text('Professional spreadsheet format'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel(exportType: exportType);
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: AppColors.error),
              title: Text('PDF (.pdf)'),
              subtitle: Text('Portable document format'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF(exportType: exportType);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMonthSelectionDialog() async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Select Month',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMonthOption(
              'Current Month',
              DateFormat('MMMM yyyy').format(currentMonth),
              currentMonth,
              () {
                Navigator.pop(context);
                _exportMonthWise(currentMonth);
              },
            ),
            const SizedBox(height: 12),
            _buildMonthOption(
              'Previous Month',
              DateFormat('MMMM yyyy').format(previousMonth),
              previousMonth,
              () {
                Navigator.pop(context);
                _exportMonthWise(previousMonth);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.calendar_today, color: AppColors.primary),
              title: Text('Select Custom Month'),
              onTap: () async {
                Navigator.pop(context);
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(2020),
                  lastDate: now,
                  initialDatePickerMode: DatePickerMode.year,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: AppColors.textOnPrimary,
                          surface: AppColors.surface,
                          onSurface: AppColors.textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  _exportMonthWise(DateTime(picked.year, picked.month));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthOption(String label, String date, DateTime month, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMonthWise(DateTime month) async {
    final monthRange = VisitorFilterService.getMonthRange(month.year, month.month);
    final monthVisitors = VisitorFilterService.applyFilters(
      visitors: _visitors,
      startDate: monthRange['start'],
      endDate: monthRange['end'],
    );

    // Temporarily set filtered visitors for export
    final originalFiltered = _filteredVisitors;
    setState(() {
      _filteredVisitors = monthVisitors;
      _startDate = monthRange['start'];
      _endDate = monthRange['end'];
    });

    await _showExportFormatDialog('month_wise');

    // Restore original filtered visitors
    setState(() {
      _filteredVisitors = originalFiltered;
    });
  }

  void _showFilterDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text(
                            'Clear All',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Status Filter
                    _buildFilterSection(
                      'Status',
                      DropdownButtonFormField<String>(
                        value: _selectedStatus ?? _allFilterValue,
                        decoration: InputDecoration(
                          labelText: 'Select Status',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                        items: _availableStatuses.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value == _allFilterValue ? null : value;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Building Filter
                    if (_availableBuildings.isNotEmpty)
                      _buildFilterSection(
                        'Building',
                        DropdownButtonFormField<String>(
                          value: _selectedBuilding ?? _allFilterValue,
                          decoration: InputDecoration(
                            labelText: 'Select Building',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          items: _availableBuildings.map((building) {
                            return DropdownMenuItem<String>(
                              value: building,
                              child: Text(building),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBuilding = value == _allFilterValue ? null : value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    if (_availableBuildings.isNotEmpty) const SizedBox(height: 20),
                    // Visitor Type Filter
                    _buildFilterSection(
                      'Visitor Type',
                      DropdownButtonFormField<String>(
                        value: _selectedVisitorType ?? _allFilterValue,
                        decoration: InputDecoration(
                          labelText: 'Select Visitor Type',
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                        items: _availableVisitorTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedVisitorType = value == _allFilterValue ? null : value;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Date Range Filter
                    _buildFilterSection(
                      'Date Range',
                      InkWell(
                        onTap: _selectDateRange,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _startDate != null && _endDate != null
                                          ? VisitorFilterService.formatDateRange(_startDate, _endDate)
                                          : 'Select date range',
                                      style: TextStyle(
                                        color: _startDate != null && _endDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textLight,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.calendar_today, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Active Filters Badge
                    if (VisitorFilterService.getActiveFilterCount(
                      status: _selectedStatus == _allFilterValue ? null : _selectedStatus,
                      building: _selectedBuilding == _allFilterValue ? null : _selectedBuilding,
                      visitorType: _selectedVisitorType == _allFilterValue ? null : _selectedVisitorType,
                      startDate: _startDate,
                      endDate: _endDate,
                      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                    ) > 0)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${VisitorFilterService.getActiveFilterCount(
                                  status: _selectedStatus == _allFilterValue ? null : _selectedStatus,
                                  building: _selectedBuilding == _allFilterValue ? null : _selectedBuilding,
                                  visitorType: _selectedVisitorType == _allFilterValue ? null : _selectedVisitorType,
                                  startDate: _startDate,
                                  endDate: _endDate,
                                  searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                                )} active filter(s) applied',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Future<void> _markExit(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorCheckOut(visitorId),
        {},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor checked out successfully',
        );
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _updateVisitorStatus(String visitorId, String newStatus) async {
    try {
      if (newStatus == 'Rejected') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reject Visitor'),
            content: const Text(
              'Are you sure you want to reject this visitor entry?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reject', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      final response = await ApiService.put(
        ApiConstants.visitorStatus(visitorId),
        {'status': newStatus},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor status updated to $newStatus',
        );
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _checkInVisitor(String visitorId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.visitorCheckIn(visitorId),
        {'checkInMethod': 'Manual'},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(
          context,
          'Visitor checked in successfully',
        );
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  Future<void> _setExactTime(String visitorId) async {
    try {
      final response = await ApiService.put(
        ApiConstants.visitorExactTime(visitorId),
        {},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(context, 'Exact time set successfully');
        _loadVisitors();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  String _formatTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime);
      final day = dt.day.toString().padLeft(2, '0');
      final month = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][dt.month - 1];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month, $hour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  String _getDurationInside(String? checkInTime) {
    if (checkInTime == null) return '';
    try {
      final dt = DateTime.parse(checkInTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      final minutes = diff.inMinutes;
      if (minutes < 60) {
        return '$minutes minutes inside';
      } else {
        final hours = minutes ~/ 60;
        final mins = minutes % 60;
        return '$hours hours $mins minutes inside';
      }
    } catch (e) {
      return '';
    }
  }

  IconData _getVisitorTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'guest':
        return Icons.person;
      case 'delivery':
        return Icons.local_shipping;
      case 'vendor':
        return Icons.build;
      case 'cab / ride':
        return Icons.local_taxi;
      case 'domestic help':
        return Icons.home;
      case 'realtor / sales':
        return Icons.business;
      case 'emergency services':
        return Icons.emergency;
      default:
        return Icons.person;
    }
  }

  Color _getVisitorTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'guest':
        return AppColors.primary;
      case 'delivery':
        return AppColors.secondaryDark;
      case 'vendor':
        return AppColors.warning;
      case 'cab / ride':
        return AppColors.error;
      case 'domestic help':
        return AppColors.secondary;
      case 'realtor / sales':
        return AppColors.info;
      case 'emergency services':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'pre-approved':
        return AppColors.info;
      case 'checked in':
        return AppColors.success;
      case 'checked out':
        return AppColors.textLight;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';
    final activeFiltersCount = [
      _selectedStatus != null && _selectedStatus != _allFilterValue,
      _selectedBuilding != null && _selectedBuilding != _allFilterValue,
      _selectedVisitorType != null && _selectedVisitorType != _allFilterValue,
      _startDate != null,
      _endDate != null,
    ].where((x) => x).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textOnPrimary),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visitors Log',
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_filteredVisitors.length} ${_filteredVisitors.length == 1 ? 'visitor' : 'visitors'}',
              style: TextStyle(
                color: AppColors.textOnPrimary.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list, color: AppColors.textOnPrimary),
                if (activeFiltersCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$activeFiltersCount',
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              _showFilterDrawer();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.textOnPrimary),
            onPressed: _showExportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search visitors...',
                hintStyle: TextStyle(color: AppColors.textLight),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),


          // Visitors List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _filteredVisitors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No visitors found',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadVisitors,
                    color: AppColors.primary,
                    backgroundColor: AppColors.background,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredVisitors.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisitorDetailScreen(
                                  visitorId: _filteredVisitors[index]['_id'],
                                ),
                              ),
                            ).then((_) => _loadVisitors());
                          },
                          child: _VisitorCard(
                            visitor: _filteredVisitors[index],
                            isResident: isResident,
                            onMarkExit: _markExit,
                            onUpdateStatus: _updateVisitorStatus,
                            onCheckIn: _checkInVisitor,
                            onSetExactTime: _setExactTime,
                            formatTime: _formatTime,
                            getDurationInside: _getDurationInside,
                            getVisitorTypeIcon: _getVisitorTypeIcon,
                            getVisitorTypeColor: _getVisitorTypeColor,
                            getStatusColor: _getStatusColor,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isResident
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NewVisitorEntryScreen(),
                  ),
                ).then((_) => _loadVisitors());
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: AppColors.textOnPrimary),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';
    
    // Don't show bottom nav for residents
    if (isResident) {
      return const SizedBox.shrink();
    }
    
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == 0) {
          // Navigate back to Dashboard without reloading
          Navigator.pop(context);
        } else {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      backgroundColor: AppColors.surface,
      elevation: 8,
      selectedFontSize: 14,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: 'Visitor Log',
        ),
      ],
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final Map<String, dynamic> visitor;
  final bool isResident;
  final Function(String) onMarkExit;
  final Function(String, String) onUpdateStatus;
  final Function(String) onCheckIn;
  final Function(String) onSetExactTime;
  final Function(String?) formatTime;
  final Function(String?) getDurationInside;
  final Function(String?) getVisitorTypeIcon;
  final Function(String?) getVisitorTypeColor;
  final Function(String) getStatusColor;

  const _VisitorCard({
    required this.visitor,
    required this.isResident,
    required this.onMarkExit,
    required this.onUpdateStatus,
    required this.onCheckIn,
    required this.onSetExactTime,
    required this.formatTime,
    required this.getDurationInside,
    required this.getVisitorTypeIcon,
    required this.getVisitorTypeColor,
    required this.getStatusColor,
  });

  Color _getStatusColorLocal(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'pre-approved':
        return AppColors.info;
      case 'checked in':
        return AppColors.success;
      case 'checked out':
        return AppColors.textLight;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textLight;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'pre-approved':
        return Icons.check_circle_outline;
      case 'checked in':
        return Icons.login;
      case 'checked out':
        return Icons.logout;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final building = visitor['building'] ?? '';
    final flatNumber = visitor['flatNumber'] ?? '';
    final checkInTime = visitor['checkInTime'] ?? visitor['entryDate'];
    final hasExited = visitor['checkOutTime'] != null;
    final status = visitor['status'] ?? 'Pending';
    final visitorType = visitor['visitorType'] ?? 'Guest';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Visitor Name and Location
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: getVisitorTypeColor(visitorType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: getVisitorTypeColor(visitorType).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  getVisitorTypeIcon(visitorType),
                  color: getVisitorTypeColor(visitorType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor['visitorName'] ?? 'Unknown Visitor',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.apartment,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$building - $flatNumber',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColorLocal(
                              status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColorLocal(status),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Login Time Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.login, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login Time',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        checkInTime != null
                            ? formatTime(checkInTime)
                            : 'Not set',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Exit Time Display (only show if visitor has exited)
          if (hasExited) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exit Time',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatTime(visitor['checkOutTime']),
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Exit Button (only show if visitor hasn't exited and user is staff/admin)
          if (!hasExited && !isResident) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showExitConfirmationDialog(context, visitor['_id']),
                icon: const Icon(Icons.exit_to_app, size: 20),
                label: const Text(
                  'Exit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showExitConfirmationDialog(
    BuildContext context,
    String visitorId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Exit Visitor',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to mark this visitor as exited? This will record the exit time.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onMarkExit(visitorId);
    }
  }
}
