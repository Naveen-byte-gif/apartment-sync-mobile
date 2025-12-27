import '../../../core/imports/app_imports.dart';
import 'flats_screen.dart';

class FloorsListScreen extends StatefulWidget {
  final String buildingCode;
  final String buildingName;
  final Map<String, dynamic>? staffData;

  const FloorsListScreen({
    super.key,
    required this.buildingCode,
    required this.buildingName,
    this.staffData,
  });

  @override
  State<FloorsListScreen> createState() => _FloorsListScreenState();
}

class _FloorsListScreenState extends State<FloorsListScreen> {
  Map<String, dynamic>? _buildingData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuildingDetails();
  }

  Future<void> _loadBuildingDetails() async {
    setState(() => _isLoading = true);
    try {
      // Use staff-specific endpoint that checks permissions
      final endpoint = ApiConstants.addBuildingCode(
        ApiConstants.staffBuildingDetails,
        widget.buildingCode,
      );
      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        setState(() {
          _buildingData = response['data']?['building'];
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final floors = _buildingData?['floors'] as List? ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.buildingName} - Floors'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : floors.isEmpty
              ? const Center(child: Text('No floors found'))
              : RefreshIndicator(
                  onRefresh: _loadBuildingDetails,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: floors.length,
                    itemBuilder: (context, index) {
                      final floor = floors[index] as Map<String, dynamic>;
                      final floorNumber = floor['floorNumber'] ?? 0;
                      final flats = floor['flats'] as List? ?? [];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$floorNumber',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            'Floor $floorNumber',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${flats.length} flats'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FlatsScreen(
                                  buildingCode: widget.buildingCode,
                                  buildingName: widget.buildingName,
                                  floorNumber: floorNumber,
                                  flats: List<Map<String, dynamic>>.from(flats),
                                  staffData: widget.staffData,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

