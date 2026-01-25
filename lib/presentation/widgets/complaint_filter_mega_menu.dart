import 'package:intl/intl.dart';
import '../../core/imports/app_imports.dart';

// Filter Mega Menu - Bottom Sheet Widget
class ComplaintFilterMegaMenu extends StatefulWidget {
  final String selectedStatus;
  final String selectedCategory;
  final String selectedPriority;
  final DateTime? startDate;
  final DateTime? endDate;
  final int activeFilterCount;
  final Function(String) onStatusChanged;
  final Function(String) onCategoryChanged;
  final Function(String) onPriorityChanged;
  final Function(DateTime?, DateTime?) onDateRangeSelected;
  final VoidCallback onClearAll;
  final VoidCallback onApply;

  const ComplaintFilterMegaMenu({
    super.key,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.selectedPriority,
    required this.startDate,
    required this.endDate,
    required this.activeFilterCount,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onDateRangeSelected,
    required this.onClearAll,
    required this.onApply,
  });

  @override
  State<ComplaintFilterMegaMenu> createState() =>
      _ComplaintFilterMegaMenuState();
}

class _ComplaintFilterMegaMenuState extends State<ComplaintFilterMegaMenu> {
  late String _tempStatus;
  late String _tempCategory;
  late String _tempPriority;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.selectedStatus;
    _tempCategory = widget.selectedCategory;
    _tempPriority = widget.selectedPriority;
    _tempStartDate = widget.startDate;
    _tempEndDate = widget.endDate;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _tempStartDate != null && _tempEndDate != null
          ? DateTimeRange(start: _tempStartDate!, end: _tempEndDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _tempStartDate = picked.start;
        _tempEndDate = picked.end;
      });
    }
  }

  int _getTempActiveFilterCount() {
    int count = 0;
    if (_tempStatus != 'all') count++;
    if (_tempCategory != 'all') count++;
    if (_tempPriority != 'all') count++;
    if (_tempStartDate != null || _tempEndDate != null) count++;
    return count;
  }

  void _applyFilters() {
    widget.onStatusChanged(_tempStatus);
    widget.onCategoryChanged(_tempCategory);
    widget.onPriorityChanged(_tempPriority);
    widget.onDateRangeSelected(_tempStartDate, _tempEndDate);
    widget.onApply();
  }

  void _resetFilters() {
    setState(() {
      _tempStatus = 'all';
      _tempCategory = 'all';
      _tempPriority = 'all';
      _tempStartDate = null;
      _tempEndDate = null;
    });
    widget.onClearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Complaints',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTempActiveFilterCount() > 0
                            ? '${_getTempActiveFilterCount()} filters active'
                            : 'Apply filters to refine results',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_getTempActiveFilterCount() > 0)
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Filter Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  _FilterSection(
                    title: 'Status',
                    icon: Icons.flag_rounded,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MegaFilterChip(
                          label: 'All',
                          isSelected: _tempStatus == 'all',
                          onTap: () => setState(() => _tempStatus = 'all'),
                        ),
                        _MegaFilterChip(
                          label: 'Open',
                          isSelected: _tempStatus == 'Open',
                          color: Colors.red,
                          onTap: () => setState(() => _tempStatus = 'Open'),
                        ),
                        _MegaFilterChip(
                          label: 'In Progress',
                          isSelected: _tempStatus == 'In Progress',
                          color: Colors.blue,
                          onTap: () =>
                              setState(() => _tempStatus = 'In Progress'),
                        ),
                        _MegaFilterChip(
                          label: 'Resolved',
                          isSelected: _tempStatus == 'Resolved',
                          color: Colors.green,
                          onTap: () => setState(() => _tempStatus = 'Resolved'),
                        ),
                        _MegaFilterChip(
                          label: 'Closed',
                          isSelected: _tempStatus == 'Closed',
                          color: Colors.grey,
                          onTap: () => setState(() => _tempStatus = 'Closed'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Category Filter
                  _FilterSection(
                    title: 'Category',
                    icon: Icons.category_rounded,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MegaFilterChip(
                          label: 'All',
                          isSelected: _tempCategory == 'all',
                          onTap: () => setState(() => _tempCategory = 'all'),
                        ),
                        _MegaFilterChip(
                          label: 'Electrical',
                          isSelected: _tempCategory == 'Electrical',
                          onTap: () =>
                              setState(() => _tempCategory = 'Electrical'),
                        ),
                        _MegaFilterChip(
                          label: 'Plumbing',
                          isSelected: _tempCategory == 'Plumbing',
                          onTap: () =>
                              setState(() => _tempCategory = 'Plumbing'),
                        ),
                        _MegaFilterChip(
                          label: 'Carpentry',
                          isSelected: _tempCategory == 'Carpentry',
                          onTap: () =>
                              setState(() => _tempCategory = 'Carpentry'),
                        ),
                        _MegaFilterChip(
                          label: 'Cleaning',
                          isSelected: _tempCategory == 'Cleaning',
                          onTap: () =>
                              setState(() => _tempCategory = 'Cleaning'),
                        ),
                        _MegaFilterChip(
                          label: 'Security',
                          isSelected: _tempCategory == 'Security',
                          onTap: () =>
                              setState(() => _tempCategory = 'Security'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Priority Filter
                  _FilterSection(
                    title: 'Priority',
                    icon: Icons.priority_high_rounded,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MegaFilterChip(
                          label: 'All',
                          isSelected: _tempPriority == 'all',
                          onTap: () => setState(() => _tempPriority = 'all'),
                        ),
                        _MegaFilterChip(
                          label: 'Emergency',
                          isSelected: _tempPriority == 'Emergency',
                          color: Colors.red,
                          onTap: () =>
                              setState(() => _tempPriority = 'Emergency'),
                        ),
                        _MegaFilterChip(
                          label: 'High',
                          isSelected: _tempPriority == 'High',
                          color: Colors.orange,
                          onTap: () => setState(() => _tempPriority = 'High'),
                        ),
                        _MegaFilterChip(
                          label: 'Medium',
                          isSelected: _tempPriority == 'Medium',
                          color: Colors.blue,
                          onTap: () => setState(() => _tempPriority = 'Medium'),
                        ),
                        _MegaFilterChip(
                          label: 'Low',
                          isSelected: _tempPriority == 'Low',
                          color: Colors.green,
                          onTap: () => setState(() => _tempPriority = 'Low'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Range Filter
                  _FilterSection(
                    title: 'Date Range',
                    icon: Icons.calendar_month_rounded,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: (_tempStartDate != null ||
                                    _tempEndDate != null)
                                ? LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.15),
                                      AppColors.primary.withOpacity(0.05),
                                    ],
                                  )
                                : null,
                            color: (_tempStartDate != null || _tempEndDate != null)
                                ? null
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_tempStartDate != null ||
                                      _tempEndDate != null)
                                  ? AppColors.primary
                                  : AppColors.border.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: (_tempStartDate != null ||
                                        _tempEndDate != null)
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _tempStartDate != null && _tempEndDate != null
                                      ? '${DateFormat('MMM d, yyyy').format(_tempStartDate!)} - ${DateFormat('MMM d, yyyy').format(_tempEndDate!)}'
                                      : 'Select date range',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: (_tempStartDate != null ||
                                            _tempEndDate != null)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: (_tempStartDate != null ||
                                            _tempEndDate != null)
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (_tempStartDate != null || _tempEndDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _tempStartDate = null;
                                      _tempEndDate = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Apply Button with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_getTempActiveFilterCount() > 0)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.error.withOpacity(0.1),
                              AppColors.error.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reset All'),
                        ),
                      ),
                    ),
                  if (_getTempActiveFilterCount() > 0)
                    const SizedBox(width: 12),
                  Expanded(
                    flex: _getTempActiveFilterCount() > 0 ? 1 : 1,
                    child: Container(
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
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _getTempActiveFilterCount() > 0
                              ? 'Apply Filters'
                              : 'Apply',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Filter Section Widget
class _FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// Mega Filter Chip Widget
class _MegaFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _MegaFilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      chipColor,
                      chipColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : AppColors.border.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: chipColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: Colors.white)
              else
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

