import '../../../core/imports/app_imports.dart';
import 'flat_details_staff_screen.dart';

class FlatsScreen extends StatefulWidget {
  final String buildingCode;
  final String buildingName;
  final int floorNumber;
  final List<Map<String, dynamic>> flats;
  final Map<String, dynamic>? staffData;

  const FlatsScreen({
    super.key,
    required this.buildingCode,
    required this.buildingName,
    required this.floorNumber,
    required this.flats,
    this.staffData,
  });

  @override
  State<FlatsScreen> createState() => _FlatsScreenState();
}

class _FlatsScreenState extends State<FlatsScreen> {
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Vacant':
        return Colors.grey;
      case 'Occupied':
        return AppColors.success;
      case 'Maintenance':
        return Colors.orange;
      case 'Reserved':
        return Colors.blue;
      case 'Blocked':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Vacant':
        return Icons.circle_outlined;
      case 'Occupied':
        return Icons.check_circle;
      case 'Maintenance':
        return Icons.build;
      case 'Reserved':
        return Icons.schedule;
      case 'Blocked':
        return Icons.block;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getFlatTypeColor(String flatType) {
    switch (flatType) {
      case '1BHK':
        return Colors.blue;
      case '2BHK':
        return Colors.green;
      case '3BHK':
        return Colors.orange;
      case '4BHK':
        return Colors.purple;
      case 'Duplex':
        return Colors.red;
      case 'Penthouse':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Floor ${widget.floorNumber} - Flats'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: widget.flats.length,
        itemBuilder: (context, index) {
          final flat = widget.flats[index];
          final status = flat['status'] ?? 'Vacant';
          final statusColor = _getStatusColor(status);
          final statusIcon = _getStatusIcon(status);
          final flatTypeColor = _getFlatTypeColor(flat['flatType'] ?? '');
          
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlatDetailsStaffScreen(
                    buildingCode: widget.buildingCode,
                    buildingName: widget.buildingName,
                    floorNumber: widget.floorNumber,
                    flatNumber: flat['flatNumber'] ?? '',
                    staffData: widget.staffData,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: flatTypeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          flat['flatType'] ?? '',
                          style: TextStyle(
                            color: flatTypeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    flat['flatNumber'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

