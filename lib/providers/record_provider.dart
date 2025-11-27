import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_record.dart';

class RecordProvider with ChangeNotifier {
  Box<String>? _settingsBox;
  List<String> _customStamps = [];

  Box<DailyRecord>? _box;
  DateTime _selectedDate = DateTime.now();
  String? _error;

  List<String> get customStamps => _customStamps;
  bool get isLoaded => _box != null;
  DateTime get selectedDate => _selectedDate;
  String? get error => _error;

  Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox<DailyRecord>('daily_records');
      _settingsBox = await Hive.openBox<String>('app_settings');
      
      // Load custom stamps
      _customStamps = _settingsBox?.values.toList() ?? [];
      
      // Normalize selected date to start of day
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    } catch (e) {
      _error = e.toString();
      print('Error initializing Hive: $e');
    }
    notifyListeners();
  }

  DailyRecord get currentRecord {
    final key = _getDateKey(_selectedDate);
    return _box?.get(key) ?? DailyRecord(date: _selectedDate);
  }

  void updateDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  Future<void> saveWeight(double? weight) async {
    final record = currentRecord;
    record.weight = weight;
    await _saveRecord(record);
  }

  Future<void> saveBodyFat(double? bodyFat) async {
    final record = currentRecord;
    record.bodyFat = bodyFat;
    await _saveRecord(record);
  }

  Future<void> saveSleepTime(double? sleepTime) async {
    final record = currentRecord;
    record.sleepTime = sleepTime;
    await _saveRecord(record);
  }

  Future<void> toggleStamp(String stamp, {List<String>? exclusiveGroup}) async {
    final record = currentRecord;
    
    if (record.stamps.contains(stamp)) {
      // If already selected, remove it
      record.stamps.remove(stamp);
    } else {
      // If adding, first check exclusive group
      if (exclusiveGroup != null) {
        for (final s in exclusiveGroup) {
          record.stamps.remove(s);
        }
      }
      record.stamps.add(stamp);
    }
    await _saveRecord(record);
  }

  Future<void> addStamp(String stamp) async {
    final record = currentRecord;
    if (!record.stamps.contains(stamp)) {
      record.stamps.add(stamp);
      await _saveRecord(record);
    }
  }

  Future<void> removeStamp(String stamp) async {
    final record = currentRecord;
    record.stamps.remove(stamp);
    await _saveRecord(record);
  }

  Future<void> addCustomStamp(String stamp) async {
    if (!_customStamps.contains(stamp)) {
      _customStamps.add(stamp);
      await _settingsBox?.add(stamp);
      notifyListeners();
    }
  }

  Future<void> removeCustomStamp(String stamp) async {
    if (_customStamps.contains(stamp)) {
      _customStamps.remove(stamp);
      // Re-save entire list to sync with Hive (simplest way for list)
      await _settingsBox?.clear();
      await _settingsBox?.addAll(_customStamps);
      notifyListeners();
    }
  }

  Future<void> addMemo(String memo) async {
    print('[RecordProvider] addMemo called with: "$memo"');
    final record = currentRecord;
    print('[RecordProvider] Record before add: ${record.memos}');
    record.memos.add(memo);
    print('[RecordProvider] Record after add: ${record.memos}');
    await _saveRecord(record);
  }

  Future<void> updateMemo(int index, String newContent) async {
    print('[RecordProvider] updateMemo called with index=$index, content="$newContent"');
    final record = currentRecord;
    print('[RecordProvider] Record before update: ${record.memos}');
    if (index >= 0 && index < record.memos.length) {
      record.memos[index] = newContent;
      print('[RecordProvider] Record after update: ${record.memos}');
      await _saveRecord(record);
    } else {
      print('[RecordProvider] Index out of range!');
    }
  }

  Future<void> removeMemo(int index) async {
    final record = currentRecord;
    if (index >= 0 && index < record.memos.length) {
      record.memos.removeAt(index);
      await _saveRecord(record);
    }
  }

  Future<void> _saveRecord(DailyRecord record) async {
    print('[RecordProvider] _saveRecord called');
    print('[RecordProvider] Record date: ${record.date}');
    print('[RecordProvider] Record memos: ${record.memos}');
    if (_box == null) {
      print('[RecordProvider] ERROR: _box is null!');
      return;
    }
    final key = _getDateKey(record.date);
    print('[RecordProvider] Saving with key: $key');
    await _box!.put(key, record);
    print('[RecordProvider] Save completed');
    notifyListeners();
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<DailyRecord> getRecentRecords(int days) {
    if (_box == null) return [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: days));

    final records = <DailyRecord>[];
    for (int i = 0; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = _getDateKey(date);
      final record = _box!.get(key);
      if (record != null) {
        records.add(record);
      }
    }
    return records;
  }
  
  List<DailyRecord> getAllRecords() {
    if (_box == null) return [];
    final records = _box!.values.toList();
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  Future<void> importData(List<DailyRecord> newRecords) async {
    if (_box == null) return;
    for (var record in newRecords) {
      final key = _getDateKey(record.date);
      await _box!.put(key, record);
    }
    notifyListeners();
  }
}
