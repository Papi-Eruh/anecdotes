import 'package:anecdotes/anecdotes.dart';
import 'package:measure_catalog/src/io/file_source.dart';

/// A measure that loops a Rive animation.
///
/// This class represents a measure that displays a Rive animation
/// that can be looped. It can also include optional captions and voice-over.
///
/// ```dart
/// const measure = LoopingRiveMeasure(
///   riveSource: FileSource('assets/rive/animation.riv'),
///   completionType: MeasureCompletionType.onTap,
/// );
/// ```
class RiveLoopingMeasure implements Measure {
  /// Creates a new instance of [RiveLoopingMeasure].
  ///
  /// The [riveSource] and [completionType] are required.
  const RiveLoopingMeasure({
    required this.riveFileSource,
    required this.completionType,
    this.voiceSource,
    this.captionList = const [],
    this.musicSource,
    this.stateMachineName,
    this.artboardName,
  }) : assert(
         completionType == MeasureCompletionType.voice ||
             completionType == MeasureCompletionType.music,
         'RiveLoopingMeasure should use either voice or music completion type.',
       );

  final FileSource riveFileSource;

  final String? stateMachineName;

  final String? artboardName;

  /// The source of the voice-over audio.
  @override
  final AudioSource? voiceSource;

  /// The type of completion for the measure.
  @override
  final MeasureCompletionType completionType;

  @override
  final List<Caption> captionList;

  @override
  final AudioSource? musicSource;
}
