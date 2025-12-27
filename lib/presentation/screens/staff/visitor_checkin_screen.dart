import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class VisitorCheckInScreen extends StatefulWidget {
  const VisitorCheckInScreen({super.key});

  @override
  State<VisitorCheckInScreen> createState() => _VisitorCheckInScreenState();
}

class _VisitorCheckInScreenState extends State<VisitorCheckInScreen> {
  final _otpController = TextEditingController();
  final _qrController = TextEditingController();
  String _checkInMethod = 'Manual'; // QR Code, OTP, Manual
  bool _isLoading = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    try {
      _scannerController = MobileScannerController();
    } catch (e) {
      print('Error initializing scanner: $e');
      // Scanner will be null, user can still use manual entry
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _qrController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkInWithQR(String qrCode) async {
    setState(() => _isLoading = true);
    try {
      // First, find visitor by QR code
      final visitorsResponse = await ApiService.get(ApiConstants.visitors);
      if (visitorsResponse['success'] == true) {
        final visitors = List<Map<String, dynamic>>.from(
          visitorsResponse['data']?['visitors'] ?? [],
        );

        final visitor = visitors.firstWhere(
          (v) => v['qrCode']?['code'] == qrCode,
          orElse: () => {},
        );

        if (visitor.isEmpty) {
          AppMessageHandler.showError(context, 'Invalid QR code');
          setState(() => _isLoading = false);
          return;
        }

        final visitorId = visitor['_id'];
        final response = await ApiService.post(
          ApiConstants.visitorCheckIn(visitorId),
          {'checkInMethod': 'QR Code', 'verificationCode': qrCode},
        );

        if (response['success'] == true) {
          AppMessageHandler.showSuccess(
            context,
            'Visitor checked in successfully',
          );
          Navigator.pop(context, true);
        } else {
          AppMessageHandler.handleResponse(context, response);
        }
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkInWithOTP(String otp) async {
    setState(() => _isLoading = true);
    try {
      // Find visitor by OTP
      final visitorsResponse = await ApiService.get(ApiConstants.visitors);
      if (visitorsResponse['success'] == true) {
        final visitors = List<Map<String, dynamic>>.from(
          visitorsResponse['data']?['visitors'] ?? [],
        );

        final visitor = visitors.firstWhere(
          (v) => v['otp']?['code'] == otp && v['status'] != 'Checked In',
          orElse: () => {},
        );

        if (visitor.isEmpty) {
          AppMessageHandler.showError(context, 'Invalid or expired OTP');
          setState(() => _isLoading = false);
          return;
        }

        final visitorId = visitor['_id'];
        final response = await ApiService.post(
          ApiConstants.visitorCheckIn(visitorId),
          {'checkInMethod': 'OTP', 'verificationCode': otp},
        );

        if (response['success'] == true) {
          AppMessageHandler.showSuccess(
            context,
            'Visitor checked in successfully',
          );
          Navigator.pop(context, true);
        } else {
          AppMessageHandler.handleResponse(context, response);
        }
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Check-In'),
        backgroundColor: AppColors.warning,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Method Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check-In Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'QR Code',
                          label: Text('QR Code'),
                          icon: Icon(Icons.qr_code),
                        ),
                        ButtonSegment(
                          value: 'OTP',
                          label: Text('OTP'),
                          icon: Icon(Icons.pin),
                        ),
                        ButtonSegment(
                          value: 'Manual',
                          label: Text('Manual'),
                          icon: Icon(Icons.edit),
                        ),
                      ],
                      selected: {_checkInMethod},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _checkInMethod = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // QR Code Scanner
            if (_checkInMethod == 'QR Code')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _scannerController != null
                              ? MobileScanner(
                                  controller: _scannerController!,
                                  onDetect: (capture) {
                                    final List<Barcode> barcodes =
                                        capture.barcodes;
                                    for (final barcode in barcodes) {
                                      if (barcode.rawValue != null &&
                                          !_isLoading) {
                                        _checkInWithQR(barcode.rawValue!);
                                        break;
                                      }
                                    }
                                  },
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Camera not available',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Use manual entry below',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _qrController,
                        decoration: InputDecoration(
                          labelText: 'Or Enter QR Code Manually',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_qrController.text.isNotEmpty) {
                                  _checkInWithQR(_qrController.text);
                                }
                              },
                        child: const Text('Check In'),
                      ),
                    ],
                  ),
                ),
              ),

            // OTP Input
            if (_checkInMethod == 'OTP')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Enter OTP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _otpController,
                        decoration: InputDecoration(
                          labelText: '6-digit OTP',
                          hintText: 'Enter OTP',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_otpController.text.length == 6) {
                                  _checkInWithOTP(_otpController.text);
                                } else {
                                  AppMessageHandler.showError(
                                    context,
                                    'Please enter 6-digit OTP',
                                  );
                                }
                              },
                        child: const Text('Check In'),
                      ),
                    ],
                  ),
                ),
              ),

            // Manual Entry
            if (_checkInMethod == 'Manual')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Manual Check-In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to visitor list for manual selection
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (_) => VisitorListScreen(),
                          //   ),
                          // );
                        },
                        icon: const Icon(Icons.list),
                        label: const Text('Select Visitor from List'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
