import 'package:floor/floor.dart';

/// A single note of the application.
///
/// The class is mapped to the `notes` table by Floor. Location columns stay
/// `null` when the user did not attach a position to the note, so the table
/// only stores what is really needed.
@Entity(tableName: 'notes')
class Note {
  const Note({
    this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationName,
  });

  /// Primary key. `null` for a note that has not been inserted yet, in that
  /// case SQLite assigns the next row id.
  @PrimaryKey(autoGenerate: true)
  final int? id;

  /// The text written by the user, always stored trimmed and non empty.
  final String content;

  /// Latitude in decimal degrees, `null` when the note has no location.
  final double? latitude;

  /// Longitude in decimal degrees, `null` when the note has no location.
  final double? longitude;

  /// Accuracy of the stored position in meters, `null` when unknown.
  final double? accuracy;

  /// Readable name of the position, for example `Cairo, Egypt`.
  ///
  /// It stays `null` when the address could not be resolved, the coordinates
  /// are stored in that case.
  final String? locationName;

  /// Time the note was created.
  final DateTime createdAt;

  /// Time the note was changed for the last time.
  final DateTime updatedAt;

  /// Whether the note carries a usable position.
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether the note has been changed after it was created.
  bool get isEdited => updatedAt.isAfter(createdAt);

  /// Returns a copy of this note with the given fields replaced.
  ///
  /// Passing `clearLocation` drops the stored position, which is needed when
  /// the user removes the location from a note.
  Note copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationName,
    bool clearLocation = false,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      accuracy: clearLocation ? null : accuracy ?? this.accuracy,
      locationName: clearLocation ? null : locationName ?? this.locationName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Note &&
        other.id == id &&
        other.content == content &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracy == accuracy &&
        other.locationName == locationName &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    latitude,
    longitude,
    accuracy,
    locationName,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Note(id: $id, content: $content)';
}
