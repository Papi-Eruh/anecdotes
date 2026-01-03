import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/internals/internals.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

/// A widget that decorates a [Measure] widget with additional functionality.
///
/// The [MeasureDecoratorWidget] is responsible for managing the voice-over
/// playback, captions, and pause/play state for a single measure. It wraps
/// the actual measure widget built by the [MeasureBuilderRegistry] and
/// provides it with the necessary context via [MeasureWidgetProvider].
class MeasureDecoratorWidget extends StatefulWidget {
  /// Creates a [MeasureDecoratorWidget].
  const MeasureDecoratorWidget({
    required this.measure,
    required this.registry,
    required this.onFinished,
    required this.controller,
    required this.isPausedStream,
    required this.captionsAdapter,
    super.key,
    this.onReady,
    this.captionsWidgetBuilder,
    this.voicePlayerBuilder,
    this.musicDurationStream,
    this.isCaptionsVisible = true,
  });

  /// The [Measure] instance to be displayed.
  final Measure measure;

  /// The registry used to build the widget for the [measure].
  final MeasureBuilderRegistry registry;

  /// A callback invoked when the measure is ready to be displayed.
  final VoidCallback? onReady;

  /// A callback invoked when the measure has finished playing.
  final VoidCallback onFinished;

  /// The controller for managing the measure's lifecycle.
  final MeasureWidgetController controller;

  /// An optional builder for customizing the display of captions.
  final CaptionsWidgetBuilder? captionsWidgetBuilder;

  /// The adapter used to parse captions from a file source.
  final CaptionsAdapter captionsAdapter;

  /// An optional builder for creating a custom [AudioPlayer] for voice-overs.
  final VoicePlayerBuilder? voicePlayerBuilder;

  /// A stream that indicates whether the anecdote is currently paused.
  final Stream<bool> isPausedStream;

  /// A stream that provides the duration of the background music for this
  /// measure.
  final Stream<Duration?>? musicDurationStream;

  /// Determines whether captions should be visible.
  final bool isCaptionsVisible;

  @override
  State<MeasureDecoratorWidget> createState() => _MeasureDecoratorWidgetState();
}

class _MeasureDecoratorWidgetState extends State<MeasureDecoratorWidget> {
  late final AudioPlayer? _voicePlayer;
  Future<void>? _voiceSetFuture;
  Future<void>? _captionsReadyFuture;
  StreamSubscription<bool>? _isPausedSubscription;
  CaptionsStreamController? _captionsStreamCtrl;
  Stream<(String?, bool)>? _captionsBuilderStream;
  Future<Duration>? _voiceDurationFuture;

  Measure get _measure => widget.measure;

  MeasureWidgetController get _controller => widget.controller;

  Stream<bool> get _isPausedStream => widget.isPausedStream;

  CaptionsWidgetBuilder? get _captionsBuilder => widget.captionsWidgetBuilder;

  void _loadVoice() {
    final voicePath = _measure.voiceSource;
    if (voicePath == null || _voicePlayer == null) return;
    _voiceSetFuture = _voicePlayer.setAudioSource(voicePath);
    _voiceDurationFuture = _voiceSetFuture?.then((_) {
      return _voicePlayer.duration!;
    });
  }

  Future<void> _onReady() async {
    await _voiceSetFuture;
    await _captionsReadyFuture;
    widget.onReady?.call();
  }

  void _onStart() {
    //todo see if we can init in initState & wait in onReady,
    //todo so that everything is in listen
    unawaited(_captionsStreamCtrl?.start());
    _isPausedSubscription = _isPausedStream.listen((isPaused) {
      if (isPaused) {
        unawaited(_voicePlayer?.pause());
        unawaited(_captionsStreamCtrl?.pause());
        return;
      }
      unawaited(_voicePlayer?.play());
      //todo see if it is called first time
      unawaited(_captionsStreamCtrl?.resume());
    });
    //todo see if it needeed unawaited(_voicePlayer?.play());
  }

  void _onFinished() {
    unawaited(_isPausedSubscription?.cancel());
    _isPausedSubscription = null;
    widget.onFinished();
  }

  void _loadCaptions() {
    _captionsStreamCtrl = CaptionsStreamControllerImpl(
      adapter: widget.captionsAdapter,
      captionsSource: _measure.captionsSource!,
    );
    _captionsReadyFuture = _captionsStreamCtrl?.load();
    _captionsBuilderStream = Rx.combineLatest2(
      _captionsStreamCtrl!.stream,
      _isPausedStream,
      (a, b) => (a, b),
    );
  }

  @override
  void initState() {
    super.initState();
    _voicePlayer = widget.voicePlayerBuilder?.call();
    _loadVoice();
    _controller.addOnStart(_onStart);
    if (_measure.captionsSource != null) _loadCaptions();
  }

  @override
  void dispose() {
    unawaited(_voicePlayer?.dispose());
    unawaited(_isPausedSubscription?.cancel());
    unawaited(_captionsStreamCtrl?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = MeasureWidgetProvider(
      onReady: _onReady,
      onFinished: _onFinished,
      isPausedStream: _isPausedStream,
      controller: _controller,
      voiceCompletedStream: _voicePlayer?.completedStream,
      musicDurationStream: widget.musicDurationStream,
      voiceDurationFuture: _voiceDurationFuture,
      child: Builder(
        builder: (context) => widget.registry.build(context, widget.measure),
      ),
    );
    return Stack(
      children: [
        child,
        if (_captionsBuilder != null)
          Visibility(
            visible: widget.isCaptionsVisible,
            maintainState: true,
            child: StreamBuilder(
              stream: _captionsBuilderStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final (captions, isPaused) = snapshot.data!;
                  return _captionsBuilder!(
                    isPaused: isPaused,
                    captions: captions,
                  );
                }
                return _captionsBuilder!(isPaused: false, captions: null);
              },
            ),
          ),
      ],
    );
  }
}

/// An [InheritedWidget] that provides measure-specific data to its descendants.
///
/// The [MeasureWidgetProvider] is used by [MeasureBaseState] to access
/// callbacks and streams related to the current measure's lifecycle, such as
/// `onReady`, `onFinished`, and pause/play events.
class MeasureWidgetProvider extends InheritedWidget {
  /// Creates a [MeasureWidgetProvider].
  const MeasureWidgetProvider({
    required super.child,
    required this.onReady,
    required this.onFinished,
    required this.controller,
    required this.isPausedStream,
    super.key,
    this.voiceCompletedStream,
    this.musicDurationStream,
    this.voiceDurationFuture,
  });

  /// A callback to be called when the measure is ready.
  final VoidCallback onReady;

  /// A callback to be called when the measure is finished.
  final VoidCallback onFinished;

  /// A stream that emits `true` when paused and `false` when playing.
  final Stream<bool> isPausedStream;

  /// The controller for the current measure widget.
  final MeasureWidgetController controller;

  /// A stream that emits when the voice-over playback is completed.
  final Stream<void>? voiceCompletedStream;

  /// A future that completes with the duration of the voice-over.
  final Future<Duration>? voiceDurationFuture;

  /// A stream that provides the duration of the background music.
  final Stream<Duration?>? musicDurationStream;

  /// Retrieves the nearest [MeasureWidgetProvider] ancestor.
  static MeasureWidgetProvider of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<MeasureWidgetProvider>();
    assert(result != null, 'No MeasureWidgetProvider found in context.');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

/// A helper class for managing completion based on a stream event.
///
/// This class simplifies the logic for awaiting the first event from a stream
/// and cleaning up the subscription.
class MeasureStreamCompletionHelper {
  /// Creates a [MeasureStreamCompletionHelper] for the given [stream].
  MeasureStreamCompletionHelper(this.stream);

  /// The stream to listen to for a completion event.
  final Stream<void>? stream;

  StreamSubscription<void>? _sub;

  /// Returns a [Future] that completes when the [stream] emits its first event.
  Future<void> resolveCompletion() {
    final completer = Completer<void>();
    _sub = stream?.listen((_) {
      if (completer.isCompleted) return;
      completer.complete();
      unawaited(_sub?.cancel());
    });
    return completer.future;
  }

  /// Cancels the stream subscription and cleans up resources.
  void dispose() => unawaited(_sub?.cancel());
}

/// An interface for a controller that manages a stream of captions.
///
/// This controller is responsible for loading caption data, parsing it, and
/// emitting caption text at the correct time.
abstract class CaptionsStreamController {
  /// The stream of caption text. Emits `null` when no caption is active.
  Stream<String?> get stream;

  /// Loads the caption data from the source.
  Future<void> load();

  /// Closes the controller and its underlying stream.
  Future<void> close();

  /// Starts emitting captions based on their timing.
  Future<void> start();

  /// Pauses the emission of captions.
  Future<void> pause();

  /// Resumes the emission of captions from where it was paused.
  Future<void> resume();
}

/// The default implementation of [CaptionsStreamController].
///
/// This controller reads caption data from a [FileSource], parses it using a
/// [CaptionsAdapter], and uses [Future.delayed] to emit caption text
/// according to the timing information in the [Captions] objects.
class CaptionsStreamControllerImpl implements CaptionsStreamController {
  CaptionsStreamControllerImpl({
    required this.adapter,
    required this.captionsSource,
  }) : _delegate = StreamController<String?>();

  final CaptionsAdapter adapter;
  final FileSource captionsSource;
  final StreamController<String?> _delegate;

  late List<Captions> _captionsList;

  Completer<void>? _pauseCompleter;
  late DateTime _lastEmitDate;
  Duration _lastWordDuration = Duration.zero;
  Duration _lastWordDoneDuration = Duration.zero;

  @override
  Stream<String?> get stream => _delegate.stream;

  @override
  Future<void> load() async {
    final visitor = FileContentVisitor();
    final fileContent = await captionsSource.accept(visitor);
    _captionsList = adapter.fromFileContent(fileContent);
  }

  @override
  Future<void> close() {
    return _delegate.close();
  }

  @override
  Future<void> start() async {
    for (final item in _captionsList) {
      await _pauseCompleter?.future;
      if (_delegate.isClosed) break;
      _delegate.add(item.text);
      _lastEmitDate = DateTime.now();
      _lastWordDuration = Duration(milliseconds: item.ms);
      await Future<void>.delayed(_lastWordDuration);
    }
    await _pauseCompleter?.future;
    if (!_delegate.isClosed) _delegate.add(null);
  }

  @override
  Future<void> pause() async {
    _lastWordDoneDuration += DateTime.now().difference(_lastEmitDate);
    _pauseCompleter = Completer<void>();
  }

  @override
  Future<void> resume() async {
    _lastEmitDate = DateTime.now();
    final duration = _lastWordDuration - _lastWordDoneDuration;
    final completer = _pauseCompleter;
    Future.delayed(duration, () {
      _lastWordDoneDuration = Duration.zero;
      _lastWordDuration = Duration.zero;
      completer?.complete();
    });
  }
}

/// A [MeasureCompletioner] that finishes a measure when the background music
/// for that measure completes.
///
/// This completioner listens to the [durationStream] and completes when the
/// duration transitions from a non-null value to `null`, which indicates
/// that the music segment for the measure has finished playing.
class MeasureMusicCompletioner implements MeasureCompletioner {
  MeasureMusicCompletioner({required this.durationStream});

  final Stream<Duration?>? durationStream;
  MeasureStreamCompletionHelper? _helper;

  @override
  void dispose() {
    _helper?.dispose();
  }

  @override
  Future<void> resolveCompletion() {
    final completionStream = durationStream?.pairwise().where(
      (pair) => pair[0] != null && pair[1] == null,
    );
    _helper = MeasureStreamCompletionHelper(completionStream);
    return _helper!.resolveCompletion();
  }
}

/// A [MeasureCompletioner] that finishes a measure when the voice-over
/// narration completes.
///
/// This completioner listens to the [completedStream] from an [AudioPlayer]
/// and completes when the stream emits an event.
class MeasureVoiceCompletioner implements MeasureCompletioner {
  MeasureVoiceCompletioner({this.completedStream});

  final Stream<void>? completedStream;
  MeasureStreamCompletionHelper? _helper;
  @override
  void dispose() {
    _helper?.dispose();
  }

  @override
  Future<void> resolveCompletion() {
    _helper = MeasureStreamCompletionHelper(completedStream);
    return _helper!.resolveCompletion();
  }
}
