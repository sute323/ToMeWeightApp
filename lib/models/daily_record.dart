import 'package:hive/hive.dart';

class DailyRecord {
  final DateTime date;
  double? weight;
  double? bodyFat;
  double? sleepTime;

  List<String> stamps;
  List<String> memos;

  DailyRecord({
    required this.date,
    this.weight,
    this.bodyFat,
    this.sleepTime,

    List<String>? stamps,
    List<String>? memos,
  })  : stamps = stamps ?? [],
        memos = memos ?? [];

  // Helper to check if the record is empty (no data entered)
  bool get isEmpty =>
      weight == null &&
      bodyFat == null &&
      sleepTime == null &&

      stamps.isEmpty &&
      memos.isEmpty;
}

class DailyRecordAdapter extends TypeAdapter<DailyRecord> {
  @override
  final int typeId = 0;

  @override
  DailyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyRecord(
      date: fields[0] as DateTime,
      weight: fields[1] as double?,
      bodyFat: fields[2] as double?,
      sleepTime: fields[3] as double?,

      stamps: (fields[4] as List?)?.cast<String>(),
      memos: (fields[5] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(6)  // Changed from 5 to 6 - we have 6 fields: date, weight, bodyFat, sleepTime, stamps, memos
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.bodyFat)
      ..writeByte(3)
      ..write(obj.sleepTime)
      ..writeByte(4)
      ..write(obj.stamps)
      ..writeByte(5)
      ..write(obj.memos);
  }
}
