import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import 'flat_layout_configuration_screen.dart';

class FlatPreviewScreen extends StatelessWidget {
  final int totalFloors;
  final Map<int, FloorFlatConfig> floorConfigs;
  final int flatsPerFloor;

  const FlatPreviewScreen({
    super.key,
    required this.totalFloors,
    required this.floorConfigs,
    required this.flatsPerFloor,
  });

  List<Map<String, dynamic>> _generatePreview() {
    List<Map<String, dynamic>> preview = [];

    for (int floorNum = 1; floorNum <= totalFloors; floorNum++) {
      final config = floorConfigs[floorNum];
      if (config == null) continue;

      // Group flats by type
      Map<String, List<String>> flatsByType = {};
      int flatIndex = 1;

      // Sort flat types for consistent ordering
      final sortedTypes = config.flatTypeCounts.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final entry in sortedTypes) {
        final flatType = entry.key;
        final count = entry.value;
        
        if (!flatsByType.containsKey(flatType)) {
          flatsByType[flatType] = [];
        }

        for (int i = 0; i < count; i++) {
          final flatNumber = '${floorNum}${flatIndex.toString().padLeft(2, '0')}';
          flatsByType[flatType]!.add(flatNumber);
          flatIndex++;
        }
      }

      preview.add({
        'floorNumber': floorNum,
        'totalFlats': config.configuredTotalFlats,
        'flatsByType': flatsByType,
      });
    }

    return preview;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _generatePreview();
    final totalFlats = preview.fold<int>(
      0,
      (sum, floor) => sum + (floor['totalFlats'] as int),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Preview'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      Icons.layers,
                      'Floors',
                      '$totalFloors',
                    ),
                    _buildSummaryItem(
                      Icons.home,
                      'Total Flats',
                      '$totalFlats',
                    ),
                    _buildSummaryItem(
                      Icons.check_circle,
                      'Configured',
                      '${preview.length}/$totalFloors',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floors Preview
          Expanded(
            child: ListView.builder(
              reverse: true, // Show top floors first
              padding: const EdgeInsets.all(16),
              itemCount: preview.length,
              itemBuilder: (context, index) {
                final floorData = preview[index];
                return _buildFloorPreviewCard(floorData);
              },
            ),
          ),

          // Action Buttons
          Container(
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
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Edit'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Confirm & Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFloorPreviewCard(Map<String, dynamic> floorData) {
    final floorNumber = floorData['floorNumber'] as int;
    final totalFlats = floorData['totalFlats'] as int;
    final flatsByType = floorData['flatsByType'] as Map<String, List<String>>;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floor Header
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'F$floorNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floor $floorNumber',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$totalFlats flat${totalFlats != 1 ? 's' : ''}',
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
            const Divider(height: 24),
            // Flat Types Grouped
            ...flatsByType.entries.map((entry) {
              final flatType = entry.key;
              final flatNumbers = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getFlatTypeColor(flatType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getFlatTypeColor(flatType).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home,
                                size: 16,
                                color: _getFlatTypeColor(flatType),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$flatType × ${flatNumbers.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getFlatTypeColor(flatType),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '→ ${flatNumbers.join(', ')}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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
}

