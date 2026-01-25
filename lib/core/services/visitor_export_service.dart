import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class VisitorExportService {
  /// Export visitors data to Excel format with professional styling
  static Future<String?> exportToExcel({
    required List<Map<String, dynamic>> visitors,
    DateTime? startDate,
    DateTime? endDate,
    String? exportType, // 'date_range' or 'month_wise'
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Visitors Log'];

      // Set column widths
      sheet.setColumnWidth(0, 25); // Visitor Name
      sheet.setColumnWidth(1, 15); // Phone Number
      sheet.setColumnWidth(2, 15); // Visitor Type
      sheet.setColumnWidth(3, 12); // Building
      sheet.setColumnWidth(4, 12); // Flat Number
      sheet.setColumnWidth(5, 15); // Status
      sheet.setColumnWidth(6, 18); // Entry Date
      sheet.setColumnWidth(7, 18); // Check In Time
      sheet.setColumnWidth(8, 18); // Check Out Time
      sheet.setColumnWidth(9, 25); // Purpose
      sheet.setColumnWidth(10, 15); // Vehicle Number

      // Track row indices manually
      int currentRow = 0;

      // Add title row with date range
      sheet.appendRow([TextCellValue('VISITORS LOG REPORT')]);
      currentRow++;

      if (startDate != null || endDate != null) {
        final dateRange = _formatDateRangeForExport(startDate, endDate);
        sheet.appendRow([TextCellValue('Date Range: $dateRange')]);
        currentRow++;
      }
      if (exportType == 'month_wise' && startDate != null) {
        sheet.appendRow([
          TextCellValue('Month: ${DateFormat('MMMM yyyy').format(startDate)}'),
        ]);
        currentRow++;
      }
      sheet.appendRow([]); // Empty row
      currentRow++;

      // Add headers with styling
      final headerColumns = 11; // Number of columns
      sheet.appendRow([
        TextCellValue('Visitor Name'),
        TextCellValue('Phone Number'),
        TextCellValue('Visitor Type'),
        TextCellValue('Building'),
        TextCellValue('Flat Number'),
        TextCellValue('Status'),
        TextCellValue('Entry Date'),
        TextCellValue('Check In Time'),
        TextCellValue('Check Out Time'),
        TextCellValue('Purpose'),
        TextCellValue('Vehicle Number'),
      ]);

      // Style header row (white text, bold)
      final headerFontColor = ExcelColor.fromHexString('#FFFFFF');
      for (int i = 0; i < headerColumns; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: headerFontColor,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      currentRow++;

      // Add data rows
      for (int i = 0; i < visitors.length; i++) {
        final visitor = visitors[i];
        sheet.appendRow([
          TextCellValue(visitor['visitorName']?.toString() ?? ''),
          TextCellValue(visitor['phoneNumber']?.toString() ?? ''),
          TextCellValue(visitor['visitorType']?.toString() ?? ''),
          TextCellValue(visitor['building']?.toString() ?? ''),
          TextCellValue(visitor['flatNumber']?.toString() ?? ''),
          TextCellValue(visitor['status']?.toString() ?? ''),
          TextCellValue(
            visitor['entryDate'] != null
                ? _formatDateForExport(visitor['entryDate'])
                : '',
          ),
          TextCellValue(
            visitor['checkInTime'] != null
                ? _formatDateForExport(visitor['checkInTime'])
                : '',
          ),
          TextCellValue(
            visitor['checkOutTime'] != null
                ? _formatDateForExport(visitor['checkOutTime'])
                : '',
          ),
          TextCellValue(visitor['purpose']?.toString() ?? ''),
          TextCellValue(visitor['vehicleNumber']?.toString() ?? ''),
        ]);

        // Apply formatting to data rows
        for (int j = 0; j < headerColumns; j++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: j, rowIndex: currentRow),
          );
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Left,
            verticalAlign: VerticalAlign.Center,
          );
        }

        // Color code status column
        final statusCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
        );
        final status = (visitor['status'] ?? '').toString().toLowerCase();
        statusCell.cellStyle = CellStyle(
          fontColorHex: _getStatusExcelColor(status),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
        currentRow++;
      }

      // Add summary row
      sheet.appendRow([]);
      currentRow++;
      sheet.appendRow([TextCellValue('Total Visitors: ${visitors.length}')]);
      final summaryCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      );
      final summaryFontColor = ExcelColor.fromHexString('#000000');
      summaryCell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: summaryFontColor,
      );

      // Get directory and save file
      final directory = await getApplicationDocumentsDirectory();
      String fileName;
      if (exportType == 'month_wise' && startDate != null) {
        fileName =
            'Visitors_Log_${DateFormat('MMMM_yyyy').format(startDate)}.xlsx';
      } else {
        fileName =
            'Visitors_Log_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      }
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      print('Error exporting to Excel: $e');
      rethrow;
    }
  }

  /// Export visitors data to PDF format with professional styling
  static Future<String?> exportToPDF({
    required List<Map<String, dynamic>> visitors,
    DateTime? startDate,
    DateTime? endDate,
    String? exportType, // 'date_range' or 'month_wise'
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VISITORS LOG REPORT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    if (startDate != null || endDate != null)
                      pw.Text(
                        'Date Range: ${_formatDateRangeForExport(startDate, endDate)}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                    if (exportType == 'month_wise' && startDate != null)
                      pw.Text(
                        'Month: ${DateFormat('MMMM yyyy').format(startDate)}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                  6: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey700,
                    ),
                    children: [
                      _buildTableCell('Name', isHeader: true),
                      _buildTableCell('Phone', isHeader: true),
                      _buildTableCell('Type', isHeader: true),
                      _buildTableCell('Building', isHeader: true),
                      _buildTableCell('Flat', isHeader: true),
                      _buildTableCell('Status', isHeader: true),
                      _buildTableCell('Entry Date', isHeader: true),
                    ],
                  ),
                  // Data rows with alternating colors
                  ...visitors.asMap().entries.map((entry) {
                    final index = entry.key;
                    final visitor = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0
                            ? PdfColors.grey100
                            : PdfColors.white,
                      ),
                      children: [
                        _buildTableCell(
                          visitor['visitorName']?.toString() ?? '',
                        ),
                        _buildTableCell(
                          visitor['phoneNumber']?.toString() ?? '',
                        ),
                        _buildTableCell(
                          visitor['visitorType']?.toString() ?? '',
                        ),
                        _buildTableCell(visitor['building']?.toString() ?? ''),
                        _buildTableCell(
                          visitor['flatNumber']?.toString() ?? '',
                        ),
                        _buildTableCell(
                          visitor['status']?.toString() ?? '',
                          statusColor: _getStatusPdfColor(
                            visitor['status']?.toString().toLowerCase() ?? '',
                          ),
                        ),
                        _buildTableCell(
                          visitor['entryDate'] != null
                              ? _formatDateForExport(visitor['entryDate'])
                              : '',
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Text(
                  'Total Visitors: ${visitors.length}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      String fileName;
      if (exportType == 'month_wise' && startDate != null) {
        fileName =
            'Visitors_Log_${DateFormat('MMMM_yyyy').format(startDate)}.pdf';
      } else {
        fileName =
            'Visitors_Log_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      }
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return filePath;
    } catch (e) {
      print('Error exporting to PDF: $e');
      rethrow;
    }
  }

  /// Share exported file
  static Future<void> shareFile(String filePath, String fileType) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Visitors Log Export - $fileType');
    } catch (e) {
      print('Error sharing file: $e');
      rethrow;
    }
  }

  /// Format date for export
  static String _formatDateForExport(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      return dateTime.toString();
    }
  }

  /// Format date range for export
  static String _formatDateRangeForExport(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate != null && endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    } else if (startDate != null) {
      return 'From ${DateFormat('dd MMM yyyy').format(startDate)}';
    } else if (endDate != null) {
      return 'Until ${DateFormat('dd MMM yyyy').format(endDate)}';
    }
    return 'All Dates';
  }

  /// Get status color for Excel
  static ExcelColor _getStatusExcelColor(String status) {
    switch (status) {
      case 'pending':
        return ExcelColor.fromHexString('#FF9800'); // Orange
      case 'pre-approved':
        return ExcelColor.fromHexString('#2196F3'); // Blue
      case 'checked in':
        return ExcelColor.fromHexString('#4CAF50'); // Green
      case 'checked out':
        return ExcelColor.fromHexString('#9E9E9E'); // Grey
      case 'rejected':
        return ExcelColor.fromHexString('#F44336'); // Red
      case 'cancelled':
        return ExcelColor.fromHexString('#F44336'); // Red
      default:
        return ExcelColor.fromHexString('#000000'); // Black
    }
  }

  /// Get status color for PDF
  static PdfColor _getStatusPdfColor(String status) {
    switch (status) {
      case 'pending':
        return PdfColors.orange;
      case 'pre-approved':
        return PdfColors.blue;
      case 'checked in':
        return PdfColors.green;
      case 'checked out':
        return PdfColors.grey;
      case 'rejected':
        return PdfColors.red;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.black;
    }
  }

  /// Build PDF table cell
  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    PdfColor? statusColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: statusColor ?? (isHeader ? PdfColors.white : PdfColors.black),
        ),
      ),
    );
  }
}
