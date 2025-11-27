import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/daily_record.dart';

class CsvHelper {
  static Future<List<DailyRecord>> pickAndParseCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String input;
        try {
          input = await file.readAsString();
        } catch (e) {
          throw Exception('Failed to read file. Please ensure it is UTF-8 encoded.');
        }

        // Check for RecStyle format
        if (input.contains('RecStyle')) { // Removed quotes check to be more permissive
          final records = _parseRecStyleCsv(input);
          if (records.isEmpty) {
             throw Exception('RecStyle format detected but no records found. Check date format.');
          }
          return records;
        }

        final records = _parseGenericCsv(input);
        if (records.isEmpty) {
           throw Exception('No valid records found. Ensure CSV has a "Date" column.');
        }
        return records;
      } else {
        // User canceled
        return [];
      }
    } catch (e) {
      // Rethrow to be handled by UI
      rethrow;
    }
  }

  static List<DailyRecord> _parseRecStyleCsv(String input) {
    List<DailyRecord> records = [];
    
    // Manual parsing to be more robust
    // Split by newline
    final lines = const LineSplitter().convert(input);
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      // Split by comma, handling potential quoted values simply (RecStyle doesn't seem to have complex nested quotes)
      // We'll just split by comma and trim quotes
      final parts = line.split(',');
      
      if (parts.isEmpty) continue;
      
      // 1. Try to parse Date from the first column
      DateTime? date;
      try {
        // Remove quotes and whitespace
        String dateStr = parts[0].trim();
        if (dateStr.startsWith('"') && dateStr.endsWith('"')) {
          dateStr = dateStr.substring(1, dateStr.length - 1);
        }
        
        // Format is yyyy/MM/dd
        if (dateStr.contains('/')) {
          final dateParts = dateStr.split('/');
          if (dateParts.length == 3) {
            date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
          }
        } else if (dateStr.contains('-')) {
           date = DateTime.parse(dateStr);
        }
      } catch (e) {
        // Not a date row, skip
        continue;
      }
      
      if (date == null) continue;
      
      // 2. Parse Weight (Col 1)
      double? weight;
      if (parts.length > 1) {
         String val = parts[1].trim();
         if (val.startsWith('"') && val.endsWith('"')) {
           val = val.substring(1, val.length - 1);
         }
         if (val != '-' && val.isNotEmpty) weight = double.tryParse(val);
      }
      
      // 3. Parse Body Fat (Col 4)
      double? bodyFat;
      if (parts.length > 4) {
         String val = parts[4].trim();
         if (val.startsWith('"') && val.endsWith('"')) {
           val = val.substring(1, val.length - 1);
         }
         if (val != '-' && val.isNotEmpty) {
           double? parsed = double.tryParse(val);
           if (parsed != null && parsed > 0) {
             bodyFat = parsed;
           }
         }
      }
      
      // 4. Parse Memo - Skipped
      List<String> memos = [];
      
      records.add(DailyRecord(
        date: date,
        weight: weight,
        bodyFat: bodyFat,
        memos: memos,
      ));
    }
    
    return records;
  }

  static List<DailyRecord> _parseGenericCsv(String input) {
    List<List<dynamic>> fields = const CsvToListConverter().convert(input);
    List<DailyRecord> records = [];
    
    int startRow = 0;
    if (fields.isNotEmpty && fields[0][0].toString().toLowerCase().contains('date')) {
      startRow = 1;
    }

    for (int i = startRow; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty) continue;

      DateTime? date;
      try {
        date = DateTime.parse(row[0].toString());
      } catch (e) {
        continue;
      }

      // Parse weight (column 1)
      double? weight;
      if (row.length > 1 && row[1].toString().isNotEmpty) {
        weight = double.tryParse(row[1].toString());
      }

      // Parse body fat (column 2)
      double? bodyFat;
      if (row.length > 2 && row[2].toString().isNotEmpty) {
        bodyFat = double.tryParse(row[2].toString());
      }

      // Parse sleep time (column 3)
      double? sleepTime;
      if (row.length > 3 && row[3].toString().isNotEmpty) {
        sleepTime = double.tryParse(row[3].toString());
      }

      // Parse stamps (column 4)
      List<String> stamps = [];
      if (row.length > 4 && row[4].toString().trim().isNotEmpty) {
        final stampsStr = row[4].toString().trim();
        // Split by space and filter out empty strings
        stamps = stampsStr.split(' ').where((s) => s.isNotEmpty).toList();
      }

      // Parse memo (column 5)
      List<String> memos = [];
      if (row.length > 5 && row[5].toString().trim().isNotEmpty) {
        memos.add(row[5].toString());
      }

      records.add(DailyRecord(
        date: date,
        weight: weight,
        bodyFat: bodyFat,
        sleepTime: sleepTime,
        stamps: stamps,
        memos: memos,
      ));
    }
    return records;
  }

  /// Export records to CSV format
  static String exportToCsv(List<DailyRecord> records) {
    if (records.isEmpty) return '';

    // Sort by date
    final sortedRecords = List<DailyRecord>.from(records);
    sortedRecords.sort((a, b) => a.date.compareTo(b.date));

    // Create CSV content
    final List<List<String>> rows = [];
    
    // Header row
    rows.add(['Date', 'Weight (kg)', 'Body Fat (%)', 'Sleep Time (h)', 'Stamps', 'Memo']);

    // Data rows
    for (var record in sortedRecords) {
      final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
      final weightStr = record.weight?.toStringAsFixed(1) ?? '';
      final bodyFatStr = record.bodyFat?.toStringAsFixed(1) ?? '';
      
      // Format sleep time as decimal hours (e.g., 7.5 for 7h30m)
      String sleepStr = '';
      if (record.sleepTime != null) {
        sleepStr = record.sleepTime!.toStringAsFixed(2);
      }

      // Combine all stamps (Mood + Exercise + Custom + Pill + Check)
      // Just join all stamps with a space
      final stampsStr = record.stamps.join(' ');

      // Memo
      final memo = record.memos.isNotEmpty ? record.memos[0] : '';

      rows.add([dateStr, weightStr, bodyFatStr, sleepStr, stampsStr, memo]);
    }

    // Convert to CSV string
    return const ListToCsvConverter().convert(rows);
  }

  /// Save CSV file to device
  static Future<bool> saveCsvFile(String csvContent) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'weight_tracker_export_$timestamp.csv';
      
      // Convert string to bytes (required for Android/iOS)
      final bytes = utf8.encode(csvContent);

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes, // Required for Android/iOS
      );

      if (outputPath != null) {
        // On desktop platforms, we still need to write the file manually
        if (!Platform.isAndroid && !Platform.isIOS) {
          final file = File(outputPath);
          await file.writeAsString(csvContent);
        }
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }
}
