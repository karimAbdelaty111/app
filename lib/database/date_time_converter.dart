import 'package:floor/floor.dart';

/// Stores [DateTime] values as milliseconds since the epoch, which is the
/// representation Floor expects for timestamps.
class DateTimeConverter extends TypeConverter<DateTime, int> {
  @override
  DateTime decode(int databaseValue) =>
      DateTime.fromMillisecondsSinceEpoch(databaseValue);

  @override
  int encode(DateTime value) => value.millisecondsSinceEpoch;
}
