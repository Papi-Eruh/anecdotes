/// {@template captions}
/// Represents a single caption with its timing information.
///
/// A [Caption] object holds the text of a caption and the start and end
/// times for its display, synchronized with an audio or video track using
/// native Dart [Duration] for high precision.
/// {@endtemplate}
class Caption {
  /// {@macro captions}
  const Caption({required this.text, required this.start, required this.end});

  /// Creates a [Caption] instance from a JSON map.
  ///
  /// The JSON map is expected to have the following keys:
  /// - `word`: The caption text.
  /// - `start_time`: The start time in seconds (double).
  /// - `end_time`: The end time in seconds (double).
  ///
  /// This factory converts the seconds (double) into high-precision [Duration]s.
  factory Caption.fromJson(Map<String, dynamic> json) {
    // Conversion Helper: Seconds (double) -> Duration (microseconds precision)
    Duration toDuration(dynamic seconds) {
      final double s = (seconds as num).toDouble();
      return Duration(microseconds: (s * 1000000).round());
    }

    return Caption(
      text: json['word'] as String,
      start: toDuration(json['start_time']),
      end: toDuration(json['end_time']),
    );
  }

  /// The text content of the caption.
  final String text;

  /// The time at which the caption should appear.
  final Duration start;

  /// The time at which the caption should disappear.
  final Duration end;

  /// The duration of the caption in milliseconds.
  /// Calculated efficiently using Duration properties.
  int get ms => (end - start).inMilliseconds;

  /// Creates a copy of this [Caption] object with the given fields replaced
  /// with new values.
  Caption copyWith({String? text, Duration? start, Duration? end}) {
    return Caption(
      text: text ?? this.text,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  /// Converts this [Caption] instance to a JSON map.
  ///
  /// Transforms the internal [Duration]s back into seconds (double)
  /// to maintain compatibility with the API format.
  Map<String, dynamic> toJson() {
    return {
      'word': text,
      'start_time': start.inMicroseconds / 1000000.0,
      'end_time': end.inMicroseconds / 1000000.0,
    };
  }

  @override
  String toString() => 'Caption(text: $text, start: $start, end: $end)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Caption &&
        other.text == text &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => text.hashCode ^ start.hashCode ^ end.hashCode;
}
