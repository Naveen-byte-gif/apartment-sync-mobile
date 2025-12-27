import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'flat_preview_screen.dart';

/// Data model for floor flat type configuration
class FloorFlatConfig {
  final int floorNumber;
  final int? totalFlats; // Optional: required flats for this floor
  final Map<String, int> flatTypeCounts; // e.g., {'1BHK': 3, '2BHK': 1}

  FloorFlatConfig({
    required this.floorNumber,
    this.totalFlats,
    Map<String, int>? flatTypeCounts,
  }) : flatTypeCounts = flatTypeCounts ?? {};

  int get configuredTotalFlats =>
      flatTypeCounts.values.fold(0, (sum, count) => sum + count);

  int get requiredTotalFlats => totalFlats ?? configuredTotalFlats;

  FloorFlatConfig copyWith({
    int? floorNumber,
    int? totalFlats,
    Map<String, int>? flatTypeCounts,
  }) {
    return FloorFlatConfig(
      floorNumber: floorNumber ?? this.floorNumber,
      totalFlats: totalFlats ?? this.totalFlats,
      flatTypeCounts: flatTypeCounts ?? Map.from(this.flatTypeCounts),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'floorNumber': floorNumber,
      'flatTypes': flatTypeCounts.entries
          .map((e) => {'type': e.key, 'count': e.value})
          .toList(),
    };
  }
}

class FlatLayoutConfigurationScreen extends StatefulWidget {
  final int totalFloors;
  final int
  flatsPerFloor; // Optional: used as default if floorsConfig not provided
  final List<FloorFlatConfig>? floorsConfig; // Optional: pre-configured floors
  final Function(List<FloorFlatConfig>) onConfigurationComplete;

  const FlatLayoutConfigurationScreen({
    super.key,
    required this.totalFloors,
    this.flatsPerFloor = 4,
    this.floorsConfig,
    required this.onConfigurationComplete,
  });

  @override
  State<FlatLayoutConfigurationScreen> createState() =>
      _FlatLayoutConfigurationScreenState();
}

class _FlatLayoutConfigurationScreenState
    extends State<FlatLayoutConfigurationScreen> {
  bool _isAutoLayoutMode = true;
  bool _showCustomizeOption = false;
  final Map<int, FloorFlatConfig> _floorConfigs = {};
  final List<String> _availableFlatTypes = [
    '1BHK',
    '2BHK',
    '3BHK',
    '4BHK',
    'Duplex',
    'Penthouse',
  ];
  final Map<int, bool> _expandedFloors = {};

  @override
  void initState() {
    super.initState();
    _initializeFloors();
  }

  void _initializeFloors() {
    // Initialize from provided floorsConfig or create defaults
    if (widget.floorsConfig != null && widget.floorsConfig!.isNotEmpty) {
      for (final config in widget.floorsConfig!) {
        _floorConfigs[config.floorNumber] = config;
        _expandedFloors[config.floorNumber] = false;
      }
      // Ensure all floors are initialized
      for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
        if (!_floorConfigs.containsKey(floorNum)) {
          _floorConfigs[floorNum] = FloorFlatConfig(
            floorNumber: floorNum,
            totalFlats: widget.flatsPerFloor,
          );
          _expandedFloors[floorNum] = false;
        }
      }
    } else {
      // Initialize with default
      for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
        final config = FloorFlatConfig(
          floorNumber: floorNum,
          totalFlats: widget.flatsPerFloor,
        );
        _floorConfigs[floorNum] = config;
        _expandedFloors[floorNum] = false;
      }
    }
  }

  void _toggleAutoLayoutMode() {
    setState(() {
      _isAutoLayoutMode = !_isAutoLayoutMode;
      if (_isAutoLayoutMode) {
        _initializeFloors();
      } else {
        _showCustomizeOption = true;
        // Initialize with default distribution for customization
        for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
          if (!_floorConfigs.containsKey(floorNum)) {
            _floorConfigs[floorNum] = FloorFlatConfig(
              floorNumber: floorNum,
              totalFlats: widget.flatsPerFloor,
            );
          }
        }
      }
    });
  }

  void _updateFlatTypeCount(int floorNumber, String flatType, int count) {
    setState(() {
      final config =
          _floorConfigs[floorNumber] ??
          FloorFlatConfig(floorNumber: floorNumber);
      final newCounts = Map<String, int>.from(config.flatTypeCounts);

      if (count <= 0) {
        newCounts.remove(flatType);
      } else {
        newCounts[flatType] = count;
      }

      _floorConfigs[floorNumber] = config.copyWith(flatTypeCounts: newCounts);
    });
  }

  int _getFlatTypeCount(int floorNumber, String flatType) {
    return _floorConfigs[floorNumber]?.flatTypeCounts[flatType] ?? 0;
  }

  int _getTotalFlatsForFloor(int floorNumber) {
    return _floorConfigs[floorNumber]?.configuredTotalFlats ?? 0;
  }

  int _getRequiredFlatsForFloor(int floorNumber) {
    // Try to get from floorsConfig first, then use flatsPerFloor
    if (widget.floorsConfig != null) {
      try {
        final config = widget.floorsConfig!.firstWhere(
          (c) => c.floorNumber == floorNumber,
        );
        return config.requiredTotalFlats;
      } catch (e) {
        return widget.flatsPerFloor;
      } 
    }
    return widget.flatsPerFloor;
  }

  bool _isFloorValid(int floorNumber) {
    final totalConfigured = _getTotalFlatsForFloor(floorNumber);
    final required = _getRequiredFlatsForFloor(floorNumber);
    return totalConfigured == required;
  }

  bool _areAllFloorsValid() {
    for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
      if (!_isFloorValid(floorNum)) return false;
    }
    return true;
  }

  int _calculateTotalFlats() {
    if (_isAutoLayoutMode) {
      return widget.totalFloors * widget.flatsPerFloor;
    }
    return _floorConfigs.values.fold<int>(
      0,
      (sum, config) => sum + config.configuredTotalFlats,
    );
  }

  List<Map<String, dynamic>> _generatePreviewData() {
    List<Map<String, dynamic>> preview = [];

    for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
      final config =
          _floorConfigs[floorNum] ?? FloorFlatConfig(floorNumber: floorNum);
      List<Map<String, dynamic>> flats = [];
      int flatIndex = 1;

      if (_isAutoLayoutMode) {
        // Auto-layout: rotate flat types
        const defaultTypes = ['1BHK', '2BHK', '3BHK', '4BHK'];
        for (int i = 1; i <= widget.flatsPerFloor; i++) {
          final flatType = defaultTypes[(i - 1) % 4];
          flats.add({
            'flatNumber': '${floorNum}${flatIndex.toString().padLeft(2, '0')}',
            'flatType': flatType,
          });
          flatIndex++;
        }
      } else {
        // Custom layout: use configured distribution
        config.flatTypeCounts.forEach((type, count) {
          for (int i = 0; i < count; i++) {
            flats.add({
              'flatNumber':
                  '${floorNum}${flatIndex.toString().padLeft(2, '0')}',
              'flatType': type,
            });
            flatIndex++;
          }
        });
      }

      preview.add({'floorNumber': floorNum, 'flats': flats});
    }

    return preview;
  }

  void _onSave() {
    if (!_isAutoLayoutMode && !_areAllFloorsValid()) {
      AppMessageHandler.showError(
        context,
        'Please configure all floors correctly. Total flats per floor must match ${widget.flatsPerFloor}',
      );
      return;
    }

    List<FloorFlatConfig> configs = [];

    // If auto layout mode, return empty list (backend will use default)
    if (_isAutoLayoutMode) {
      widget.onConfigurationComplete(configs);
      return;
    }

    // Custom layout: return all configured floors
    // Ensure all floors are included with proper validation
    for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
      final config = _floorConfigs[floorNum];
      if (config != null) {
        // Validate that floor has correct number of flats
        if (config.totalFlats == widget.flatsPerFloor) {
          configs.add(config);
        } else {
          // If floor doesn't have correct flats, add empty config (will use default)
          // But this shouldn't happen as we validate before saving
          AppMessageHandler.showError(
            context,
            'Floor $floorNum has ${config.totalFlats} flats, but expected ${widget.flatsPerFloor}',
          );
          return;
        }
      } else {
        // Floor not configured, add empty config (backend will use default)
        configs.add(FloorFlatConfig(floorNumber: floorNum));
      }
    }

    widget.onConfigurationComplete(configs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flat Layout Configuration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with Auto Layout Toggle
          _buildHeader(),

          // Main Content: Floor Configuration
          Expanded(
            child: _buildFloorConfigurationPanel(),
          ),

          // Bottom Action Bar
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto Layout Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isAutoLayoutMode
                      ? 'Flat types will be automatically distributed across floors'
                      : 'Customize flat types for each floor',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAutoLayoutMode,
            onChanged: (_) => _toggleAutoLayoutMode(),
            activeColor: AppColors.primary,
          ),
          if (!_isAutoLayoutMode) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _toggleAutoLayoutMode,
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Customize Layout'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloorConfigurationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isAutoLayoutMode
                      ? 'Auto Layout Preview'
                      : 'Floor-wise Configuration',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isAutoLayoutMode && widget.totalFloors > 1)
                TextButton.icon(
                  onPressed: () => _showBulkActionsDialog(),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Bulk Actions'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.totalFloors,
              itemBuilder: (context, index) {
                final floorNum =
                    widget.totalFloors -
                    index; // Show floors from top to bottom
                return _buildFloorAccordion(floorNum);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkActionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all, color: AppColors.primary),
              title: const Text('Copy First Floor to All'),
              subtitle: const Text('Apply Floor 1 configuration to all floors'),
              onTap: () {
                Navigator.pop(context);
                _applyToAllFloors(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers_clear, color: AppColors.error),
              title: const Text('Clear All Floors'),
              subtitle: const Text('Remove all flat type configurations'),
              onTap: () {
                Navigator.pop(context);
                _clearAllFloors();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _clearAllFloors() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Floors?'),
        content: const Text(
          'This will remove all flat type configurations from all floors. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
                  _clearFloor(floorNum);
                }
              });
              Navigator.pop(context);
              AppMessageHandler.showSuccess(
                context,
                'All floors cleared',
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorAccordion(int floorNumber) {
    final isExpanded = _expandedFloors[floorNumber] ?? false;
    final isValid = _isFloorValid(floorNumber);
    final totalFlats = _getTotalFlatsForFloor(floorNumber);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'F$floorNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Floor $floorNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isAutoLayoutMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isValid
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalFlats / ${widget.flatsPerFloor}',
                    style: TextStyle(
                      color: isValid ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: !_isAutoLayoutMode && !isValid
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Configure ${_getRequiredFlatsForFloor(floorNumber) - totalFlats} more flat${_getRequiredFlatsForFloor(floorNumber) - totalFlats != 1 ? 's' : ''}',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                )
              : null,
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.primary,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedFloors[floorNumber] = expanded;
            });
          },
          children: [
            if (_isAutoLayoutMode)
              _buildAutoLayoutInfo(floorNumber)
            else
              _buildFloorCustomization(floorNumber),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoLayoutInfo(int floorNumber) {
    const defaultTypes = ['1BHK', '2BHK', '3BHK', '4BHK'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Auto Layout Distribution',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.flatsPerFloor, (index) {
              final flatType = defaultTypes[index % 4];
              final flatNumber =
                  '${floorNumber}${(index + 1).toString().padLeft(2, '0')}';
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    flatNumber.substring(flatNumber.length - 2),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                label: Text(flatType),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                labelStyle: const TextStyle(fontSize: 12),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _copyFromFloor(int targetFloor, int sourceFloor) {
    final sourceConfig = _floorConfigs[sourceFloor];
    if (sourceConfig != null) {
      setState(() {
        _floorConfigs[targetFloor] = FloorFlatConfig(
          floorNumber: targetFloor,
          totalFlats: _getRequiredFlatsForFloor(targetFloor),
          flatTypeCounts: Map<String, int>.from(sourceConfig.flatTypeCounts),
        );
      });
      AppMessageHandler.showSuccess(
        context,
        'Copied configuration from Floor $sourceFloor to Floor $targetFloor',
      );
    }
  }

  void _applyToAllFloors(int sourceFloor) {
    final sourceConfig = _floorConfigs[sourceFloor];
    if (sourceConfig != null) {
      setState(() {
        for (int floorNum = 1; floorNum <= widget.totalFloors; floorNum++) {
          if (floorNum != sourceFloor) {
            _floorConfigs[floorNum] = FloorFlatConfig(
              floorNumber: floorNum,
              totalFlats: _getRequiredFlatsForFloor(floorNum),
              flatTypeCounts: Map<String, int>.from(sourceConfig.flatTypeCounts),
            );
          }
        }
      });
      AppMessageHandler.showSuccess(
        context,
        'Applied Floor $sourceFloor configuration to all other floors',
      );
    }
  }

  void _clearFloor(int floorNumber) {
    setState(() {
      _floorConfigs[floorNumber] = FloorFlatConfig(
        floorNumber: floorNumber,
        totalFlats: _getRequiredFlatsForFloor(floorNumber),
        flatTypeCounts: {},
      );
    });
  }

  Widget _buildDynamicFlatTypeList(int floorNumber) {
    final config = _floorConfigs[floorNumber];
    final configuredTypes = config?.flatTypeCounts.keys.toList() ?? [];
    final availableTypes = _availableFlatTypes
        .where((type) => !configuredTypes.contains(type))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Configured Flat Types
        ...configuredTypes.map((flatType) {
          final count = _getFlatTypeCount(floorNumber, flatType);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Row: Flat Type Badge and Remove Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flat Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getFlatTypeColor(flatType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getFlatTypeColor(flatType).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          flatType,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getFlatTypeColor(flatType),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Remove Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _updateFlatTypeCount(
                          floorNumber,
                          flatType,
                          0,
                        ),
                        color: AppColors.error,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second Row: Count Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: count > 1
                            ? () => _updateFlatTypeCount(
                                floorNumber,
                                flatType,
                                count - 1,
                              )
                            : null,
                        color: AppColors.primary,
                      ),
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          final required = _getRequiredFlatsForFloor(floorNumber);
                          final current = _getTotalFlatsForFloor(floorNumber);
                          if (current < required) {
                            _updateFlatTypeCount(
                              floorNumber,
                              flatType,
                              count + 1,
                            );
                          } else {
                            AppMessageHandler.showError(
                              context,
                              'Total flats cannot exceed ${required}',
                            );
                          }
                        },
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),

        // Add Flat Type Button
        if (availableTypes.isNotEmpty)
          InkWell(
            onTap: () => _showAddFlatTypeDialog(floorNumber, availableTypes),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Add Flat Type',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showAddFlatTypeDialog(int floorNumber, List<String> availableTypes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Flat Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableTypes.map((type) {
            return ListTile(
              leading: Icon(
                Icons.home,
                color: _getFlatTypeColor(type),
              ),
              title: Text(type),
              onTap: () {
                Navigator.pop(context);
                _updateFlatTypeCount(floorNumber, type, 1);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Color _getFlatTypeColor(String flatType) {
    switch (flatType) {
      case '1BHK':
        return AppColors.info;
      case '2BHK':
        return AppColors.success;
      case '3BHK':
        return AppColors.warning;
      case '4BHK':
        return AppColors.primary;
      case 'Duplex':
        return AppColors.secondary;
      case 'Penthouse':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildFloorCustomization(int floorNumber) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Actions Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Copy from another floor
                  if (widget.totalFloors > 1)
                    PopupMenuButton<int>(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14, color: AppColors.info),
                            const SizedBox(width: 4),
                            const Text(
                              'Copy From',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.info,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (context) {
                        return List.generate(widget.totalFloors, (index) {
                          final sourceFloor = index + 1;
                          if (sourceFloor == floorNumber) {
                            return const PopupMenuItem(
                              enabled: false,
                              child: Text('Current Floor'),
                            );
                          }
                          return PopupMenuItem(
                            value: sourceFloor,
                            child: Text('Floor $sourceFloor'),
                          );
                        });
                      },
                      onSelected: (sourceFloor) {
                        _copyFromFloor(floorNumber, sourceFloor);
                      },
                    ),
                  // Apply to all floors
                  if (widget.totalFloors > 1)
                    InkWell(
                      onTap: () => _applyToAllFloors(floorNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.layers,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Apply to All',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Clear floor
                  InkWell(
                    onTap: () => _clearFloor(floorNumber),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Dynamic Flat Type List
        _buildDynamicFlatTypeList(floorNumber),

        // Current Distribution Summary
        const Divider(),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Distribution:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _floorConfigs[floorNumber]?.flatTypeCounts.entries
                      .where((e) => e.value > 0)
                      .map(
                        (e) => Chip(
                          label: Text('${e.key} × ${e.value}'),
                          backgroundColor: AppColors.success.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      .toList() ??
                  [],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    final previewData = _generatePreviewData();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Live Preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              reverse: true, // Show top floors first
              itemCount: previewData.length,
              itemBuilder: (context, index) {
                final floorData = previewData[index];
                return _buildPreviewFloorCard(floorData);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewFloorCard(Map<String, dynamic> floorData) {
    final floorNumber = floorData['floorNumber'] as int;
    final flats = floorData['flats'] as List<Map<String, dynamic>>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Floor $floorNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: flats.map((flat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getFlatTypeColor(
                      flat['flatType'] as String,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getFlatTypeColor(
                        flat['flatType'] as String,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        flat['flatNumber'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getFlatTypeColor(flat['flatType'] as String),
                        ),
                      ),
                      Text(
                        flat['flatType'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreviewScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FlatPreviewScreen(
          totalFloors: widget.totalFloors,
          floorConfigs: _floorConfigs,
          flatsPerFloor: widget.flatsPerFloor,
        ),
      ),
    );

    if (result == true) {
      // User confirmed from preview, save configuration
      _onSave();
    }
  }

  Widget _buildActionBar() {
    final isValid = _isAutoLayoutMode || _areAllFloorsValid();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Flats: ${_calculateTotalFlats()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _isAutoLayoutMode
                      ? 'Auto layout will be applied'
                      : isValid
                          ? 'All floors configured correctly'
                          : 'Please fix floor configurations',
                  style: TextStyle(
                    fontSize: 12,
                    color: isValid ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isValid ? _openPreviewScreen : null,
            icon: const Icon(Icons.preview),
            label: const Text('Preview'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
