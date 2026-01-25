import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Service for managing visitor filters
class VisitorFilterService {
  /// Apply filters to visitor list
  static List<Map<String, dynamic>> applyFilters({
    required List<Map<String, dynamic>> visitors,
    String? status,
    String? building,
    String? visitorType,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    List<Map<String, dynamic>> filtered = List.from(visitors);

    // Status filter
    if (status != null && status != 'All') {
      filtered = filtered.where((visitor) {
        final visitorStatus = (visitor['status'] ?? '').toString();
        return visitorStatus.toLowerCase() == status.toLowerCase();
      }).toList();
    }

    // Building filter
    if (building != null && building != 'All') {
      filtered = filtered.where((visitor) {
        final visitorBuilding = (visitor['building'] ?? '').toString().toUpperCase();
        return visitorBuilding == building.toUpperCase();
      }).toList();
    }

    // Visitor type filter
    if (visitorType != null && visitorType != 'All') {
      filtered = filtered.where((visitor) {
        final type = (visitor['visitorType'] ?? '').toString();
        return type == visitorType;
      }).toList();
    }

    // Date range filter
    if (startDate != null || endDate != null) {
      filtered = filtered.where((visitor) {
        try {
          final entryDate = visitor['entryDate'];
          if (entryDate == null) return false;

          final date = DateTime.parse(entryDate.toString());
          final dateOnly = DateTime(date.year, date.month, date.day);

          if (startDate != null && endDate != null) {
            final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
            final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
            return dateOnly.isAfter(startOnly.subtract(const Duration(days: 1))) &&
                   dateOnly.isBefore(endOnly.add(const Duration(days: 1)));
          } else if (startDate != null) {
            final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
            return dateOnly.isAfter(startOnly.subtract(const Duration(days: 1)));
          } else if (endDate != null) {
            final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
            return dateOnly.isBefore(endOnly.add(const Duration(days: 1)));
          }
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Search query filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((visitor) {
        final name = (visitor['visitorName'] ?? '').toString().toLowerCase();
        final phone = (visitor['phoneNumber'] ?? '').toString().toLowerCase();
        final flat = (visitor['flatNumber'] ?? '').toString().toLowerCase();
        final building = (visitor['building'] ?? '').toString().toLowerCase();
        final type = (visitor['visitorType'] ?? '').toString().toLowerCase();
        
        return name.contains(query) ||
               phone.contains(query) ||
               flat.contains(query) ||
               building.contains(query) ||
               type.contains(query);
      }).toList();
    }

    return filtered;
  }

  /// Get active filter count
  static int getActiveFilterCount({
    String? status,
    String? building,
    String? visitorType,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    int count = 0;
    if (status != null && status != 'All') count++;
    if (building != null && building != 'All') count++;
    if (visitorType != null && visitorType != 'All') count++;
    if (startDate != null) count++;
    if (endDate != null) count++;
    if (searchQuery != null && searchQuery.isNotEmpty) count++;
    return count;
  }

  /// Format date range for display
  static String formatDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    } else if (startDate != null) {
      return 'From ${DateFormat('dd MMM yyyy').format(startDate)}';
    } else if (endDate != null) {
      return 'Until ${DateFormat('dd MMM yyyy').format(endDate)}';
    }
    return 'All Dates';
  }

  /// Get month range for month-wise export
  static Map<String, DateTime> getMonthRange(int year, int month) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    return {
      'start': startDate,
      'end': endDate,
    };
  }

  /// Get current month range
  static Map<String, DateTime> getCurrentMonthRange() {
    final now = DateTime.now();
    return getMonthRange(now.year, now.month);
  }

  /// Get previous month range
  static Map<String, DateTime> getPreviousMonthRange() {
    final now = DateTime.now();
    final previousMonth = now.month == 1 ? 12 : now.month - 1;
    final previousYear = now.month == 1 ? now.year - 1 : now.year;
    return getMonthRange(previousYear, previousMonth);
  }
}

