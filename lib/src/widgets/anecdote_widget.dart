import 'dart:async';
import 'dart:convert';

import 'package:anecdotes/src/internals/internals.dart';
import 'package:anecdotes/src/models/models.dart';
import 'package:anecdotes/src/widgets/anecdote_widget_impl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:maestro/maestro.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Signature for a function that builds a widget for displaying captions.
///
/// The [captions] parameter contains the text currently being displayed.
/// It can be `null` to indicate that no caption should be shown (for example,
/// during silent parts or after the end of playback).
typedef CaptionsWidgetBuilder =
    Widget Function({required bool isPaused, String? captions});

/// Signature for a function that builds a widget for displaying pause state.
/// It should build a pause icon to show user the widget is in pause state and
/// possibly other options that are visible only on paused.
// In this case it's more simple to implement on widget.
// ignore: avoid_positional_boolean_parameters
typedef PauseWidgetBuilder = Widget Function(bool isPaused);

/// Signature for a function that builds a new AudioPlayer.
typedef VoicePlayerBuilder = AudioPlayer Function();

/// Signature for a function that builds a [MeasureBaseWidget]
/// consuming a Measure.
typedef MeasureWidgetBuilder<M extends Measure> =
    MeasureBaseWidget Function(BuildContext context, M measure);

/// {@template captions_adapter}
/// A base class for adapters that convert raw file content
/// (such as JSON, XML, or plain text) into a list of [Captions].
/// {@endtemplate}
abstract class CaptionsAdapter {
  /// {@macro captions_adapter}
  const CaptionsAdapter();

  /// Converts the given [fileContent] into a list of [Captions].
  ///
  /// Implementations should parse the provided string and return a list of
  /// captions with their corresponding start and end times.
  List<Captions> fromFileContent(String fileContent);
}

/// A [CaptionsAdapter] for parsing JSON-formatted caption files.
///
/// This adapter assumes the file content is a JSON array where each object
/// can be parsed by [Captions.fromJson].
class JsonCaptionsAdapter implements CaptionsAdapter {
  /// Creates an adapter for JSON-formatted captions.
  const JsonCaptionsAdapter();

  @override
  List<Captions> fromFileContent(String fileContent) {
    final captionsList = (jsonDecode(fileContent) as List<dynamic>)
        .cast<Json>()
        .map(Captions.fromJson)
        .toList();
    return captionsList;
  }
}

/// Controls an [AnecdoteWidget] to allow deferred starting of playback.
///
/// This controller can be passed to an [AnecdoteWidget] to trigger the
/// start of the anecdote externally.
abstract final class AnecdoteWidgetController {
  /// Creates a new [AnecdoteWidgetController].
  factory AnecdoteWidgetController() => _AncWidgetController();

  /// Returns `true` if the [start] method has been called.
  bool get isStarted;

  //
  //ignore: avoid_setters_without_getters
  set _onStart(VoidCallback callback);

  /// Starts the anecdote playback.
  ///
  /// If the anecdote is already started, this method has no effect.
  void start();
}

/// Controls a [MeasureBaseWidget] to manage its lifecycle.
///
/// This controller is provided internally to each measure widget and allows
/// for adding callbacks to be executed when the measure starts.
abstract final class MeasureWidgetController {
  /// Adds a callback to be executed when the measure starts.
  void addOnStart(VoidCallback? callback);

  /// Starts the measure.
  void start();
}

/// Basic implementation of [MeasureWidgetController]
@visibleForTesting
final class MeasureWidgetControllerImpl implements MeasureWidgetController {
  VoidCallback? _onStart;

  @override
  void start() => _onStart?.call();

  @override
  void addOnStart(VoidCallback? callback) {
    _onStart = _onStart.then(callback);
  }
}

final class _AncWidgetController implements AnecdoteWidgetController {
  @override
  VoidCallback? _onStart;

  @override
  bool isStarted = false;

  @override
  void start() {
    _onStart?.call();
    isStarted = true;
  }
}

/// A registry that maps [Measure] types to their corresponding widget builders.
///
/// The [MeasureBuilderRegistry] is responsible for constructing widgets
/// for specific [Measure] instances using
/// the registered [MeasureWidgetBuilder].
///
/// This allows you to decouple the creation logic of measure widgets
/// from their usage, similar to a dependency injector or factory pattern.
///
/// ```dart
/// final registry = MeasureBuilderRegistry()
///   ..register<MyMeasure>((context, measure) => MyMeasureWidget(measure))
///   ..register<AnotherMeasure>((context, measure) => AnotherMeasureWidget(measure));
///
/// final measure = MyMeasure();
/// final widget = registry.build(context, measure); // Returns a MyMeasureWidget
/// ```
abstract final class MeasureBuilderRegistry {
  /// Creates a new instance of the default implementation.
  factory MeasureBuilderRegistry() => _MeasureBuilderRegistry();

  /// Builds a widget for the given [measure] using the registered builder.
  ///
  /// Throws a [ArgumentError] if no builder is
  /// registered for the [measure]’s type.
  Widget build(BuildContext context, Measure measure);

  /// Registers a [builder] for a specific [Measure] subtype [M].
  ///
  /// If a builder is already registered for [M], it will be replaced.
  ///
  /// Example:
  /// ```dart
  /// registry.register<MyMeasure>(
  ///   (context, measure) => MyMeasureWidget(measure),
  /// );
  /// ```
  void register<M extends Measure>(MeasureWidgetBuilder<M> builder);
}

final class _MeasureBuilderRegistry implements MeasureBuilderRegistry {
  _MeasureBuilderRegistry() : builderByType = {};

  final Map<Type, MeasureWidgetBuilder> builderByType;

  @override
  void register<M extends Measure>(MeasureWidgetBuilder<M> builder) {
    builderByType[M] = (context, measure) {
      if (measure is! M) throw ArgumentError('Wrong register $M');
      return builder(context, measure);
    };
  }

  @override
  Widget build(BuildContext context, Measure measure) {
    final key = measure.runtimeType;
    final builder = builderByType[key];
    if (builder == null) throw Exception('No builder for $key');
    return builder(context, measure);
  }
}

/// A widget that displays and manages the playback of a single [Anecdote].
///
/// The [AnecdoteWidget] orchestrates the sequence of [Measure]s, handles
/// music and voice-over playback, displays captions, and manages user
/// interactions. It is highly customizable through various builders and
/// adapters, allowing developers to define how each component of the
/// anecdote is rendered and behaves.
///
/// Use this widget to display a single, self-contained anecdote. For
/// displaying a series of anecdotes, consider using [AnecdoteCarousel].
///
/// ```dart
/// final myAnecdote = MyAnecdote();
/// final myRegistry = MeasureBuilderRegistry()
///   ..register<MyMeasure>((context, measure) => MyMeasureWidget(measure));
///
/// AnecdoteWidget(
///   anecdote: myAnecdote,
///   measureBuilderRegistry: myRegistry,
///   musicPlayer: myMusicPlayer,
///   onFinished: () => print('Anecdote finished!'),
/// );
/// ```
class AnecdoteWidget extends StatefulWidget {
  /// Creates a widget to display an anecdote.
  const AnecdoteWidget({
    required this.anecdote,
    required this.measureBuilderRegistry,
    super.key,
    this.controller,
    this.musicPlayer,
    this.voicePlayerBuilder,
    this.captionsAdapter = const JsonCaptionsAdapter(),
    this.captionsWidgetBuilder,
    this.pauseWidgetBuilder,
    this.onReady,
    this.onFinished,
    this.loop = false,
    this.isInteractive = true,
    this.isWakelockedManaged = true,
    this.isCaptionsVisible = true,
    this.indexMeasureStart = 0,
    AncMusicBehavior? musicBehavior,
  }) : musicBehavior = musicBehavior ?? AncMusicBehavior.scoped;

  /// The [Anecdote] to be displayed, containing a sequence of [Measure]s.
  final Anecdote anecdote;

  /// The registry used to resolve the appropriate widget builder for each
  /// [Measure] subtype.
  final MeasureBuilderRegistry measureBuilderRegistry;

  /// An optional controller to manage the anecdote's playback externally.
  final AnecdoteWidgetController? controller;

  /// The [MusicPlayer] instance responsible for handling background music.
  final MusicPlayer? musicPlayer;

  /// An optional builder for creating a custom [AudioPlayer] for voice-overs.
  final VoicePlayerBuilder? voicePlayerBuilder;

  /// The adapter used to parse captions from a file source.
  ///
  /// Defaults to [JsonCaptionsAdapter].
  final CaptionsAdapter captionsAdapter;

  /// An optional builder to customize the display of captions.
  ///
  /// If not provided, captions will not be displayed.
  final CaptionsWidgetBuilder? captionsWidgetBuilder;

  /// An optional builder to customize the widget shown when playback is paused.
  final PauseWidgetBuilder? pauseWidgetBuilder;

  /// A callback invoked when the first [Measure] is ready to be displayed.
  final VoidCallback? onReady;

  /// A callback invoked when the anecdote has finished playing.
  final VoidCallback? onFinished;

  /// Determines whether the anecdote should loop back to the beginning after
  /// finishing.
  ///
  /// Defaults to `false`.
  final bool loop;

  /// Determines whether user interactions (e.g., taps) can control playback.
  ///
  /// Defaults to `true`.
  final bool isInteractive;

  /// Defines how background music should behave when the anecdote is active.
  ///
  /// See [AncMusicBehavior] for available options. Defaults to
  /// [AncMusicBehavior.scoped].
  final AncMusicBehavior musicBehavior;

  /// If `true`, the device screen will be kept awake during playback.
  ///
  /// Defaults to `true`.
  final bool isWakelockedManaged;

  /// Determines whether captions should be visible.
  ///
  /// Defaults to `true`.
  final bool isCaptionsVisible;

  /// The index of the measure in [Anecdote.measures] at which to start
  /// playback.
  ///
  /// Defaults to `0`.
  final int indexMeasureStart;

  @override
  State<AnecdoteWidget> createState() => _AnecdoteWidgetState();
}

class _AnecdoteWidgetState extends State<AnecdoteWidget>
    with WidgetsBindingObserver {
  late final _ancStateSubject = BehaviorSubject<AncState>.seeded(AncState.init);

  /// Current index
  late final _cIndexSubject = BehaviorSubject<int>.seeded(_indexMeasureStart);

  /// [0] for next, [1] for current
  final _measureControllers = [
    MeasureWidgetControllerImpl(),
    MeasureWidgetControllerImpl(),
  ];

  final _musicReadyCompleter = Completer<void>();

  late final Stream<bool> _isAncPausedStream = _ancStateSubject
      .map((event) => event.isPaused)
      .distinct();

  var _isStarted = false;

  StreamSubscription<AncState>? _ancStateSubscription;

  MusicPlayer? get _musicPlayer => widget.musicPlayer;

  List<Measure> get _measures => widget.anecdote.measures;

  int get _measureCount => _measures.length;

  AncMusicBehavior get _behavior => widget.musicBehavior;

  AnecdoteWidgetController? get _controller => widget.controller;

  bool get _isWakelockedManaged => widget.isWakelockedManaged;

  int get _indexMeasureStart => widget.indexMeasureStart;

  Future<void> _start() async {
    if (_isStarted) throw Exception('The anecdote is already started.');
    if (!mounted) return;
    await _loadMusic();
    _ancStateSubject.add(AncState.playing);
    _measureControllers.last.start();
    _isStarted = true;
  }

  void _goNextMeasure() {
    ancLogger.info('Going next measure.');
    final nextIndex = _cIndexSubject.value + 1;
    final nextRealIndex = nextIndex % _measureCount;
    final hasReachedEndLastMeasure = nextRealIndex == 0;
    if (hasReachedEndLastMeasure) {
      ancLogger.info('Reached end of last measure.');
      unawaited(_musicPlayer?.seek(Duration.zero));
      if (!widget.loop) {
        ancLogger.info('AncState => Finished.');
        _ancStateSubject.add(AncState.finished);
        return widget.onFinished?.call();
      }
    }
    if (!mounted) return;
    _cIndexSubject.add(nextIndex);
    _measureControllers[1] = _measureControllers[0]..start();
    _measureControllers[0] = MeasureWidgetControllerImpl();
  }

  Future<void> _loadMusic() async {
    final musicSource = widget.anecdote.musicSource;
    if (musicSource == null) return;
    if (_behavior.isPushed) {
      await _musicPlayer?.pushAudioSource(
        musicSource,
        initialIndex: _indexMeasureStart,
      );
    } else {
      await _musicPlayer?.replaceAudioSource(
        musicSource,
        initialIndex: _indexMeasureStart,
      );
    }
    _musicReadyCompleter.complete();
  }

  @override
  void initState() {
    super.initState();
    if (_isWakelockedManaged) unawaited(WakelockPlus.enable());
    WidgetsBinding.instance.addObserver(this);
    _controller?._onStart = _start;
    _ancStateSubscription = _ancStateSubject
        .where((state) => state.isVisible)
        .listen((state) {
          if (state == AncState.paused) {
            unawaited(_musicPlayer?.pause());
          } else if (state == AncState.playing) {
            unawaited(_musicPlayer?.play());
          }
        });
  }

  @override
  void dispose() {
    if (_isWakelockedManaged) unawaited(WakelockPlus.disable());
    WidgetsBinding.instance.removeObserver(this);
    if (_behavior.isScoped) unawaited(_musicPlayer?.pop());
    unawaited(_ancStateSubject.close());
    unawaited(_ancStateSubscription?.cancel());
    unawaited(_cIndexSubject.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ancStateSubject.value.isFinished) return;
    final isResumed = state == AppLifecycleState.resumed;
    if (isResumed) _ancStateSubject.add(AncState.playing);
    if (state == AppLifecycleState.inactive) {
      _ancStateSubject.add(AncState.paused);
    }
  }

  Stream<Duration?> _musicDurationStream(int measureIndex) async* {
    await _musicReadyCompleter.future;
    if (_musicPlayer != null) {
      yield* _musicPlayer!.durationStreamByIndex(measureIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = widget.measureBuilderRegistry;
    return GestureDetector(
      onTap: widget.isInteractive.then(
        () => _ancStateSubject.add(_ancStateSubject.value.next),
      ),
      child: StreamBuilder(
        stream: _cIndexSubject.map((index) {
          final current = (
            index % _measureCount,
            index ~/ _measureCount,
            index,
          );
          final incrIndex = index + 1;
          final next = (
            incrIndex % _measureCount,
            incrIndex ~/ _measureCount,
            incrIndex,
          );
          return [next, current];
        }),
        builder: (context, snapshot) {
          final indexTurnList = snapshot.data ?? [];
          return Stack(
            children: [
              ...indexTurnList.mapIndexed((controllerIndex, tuple) {
                final (measureIndex, turn, index) = tuple;
                final measure = _measures[measureIndex];
                final onReady = (index == _indexMeasureStart && !_isStarted)
                    .then(
                      widget.onReady.then((_controller == null).then(_start)),
                    );
                final isMeasurePausedStream = _cIndexSubject
                    .map((event) => event == index)
                    .distinct()
                    .whenTrueSwitchTo(_isAncPausedStream);
                return MeasureDecoratorWidget(
                  key: ValueKey('${measureIndex}_$turn'),
                  measure: measure,
                  onReady: onReady,
                  onFinished: _goNextMeasure,
                  controller: _measureControllers[controllerIndex],
                  registry: registry,
                  captionsWidgetBuilder: widget.captionsWidgetBuilder,
                  voicePlayerBuilder: widget.voicePlayerBuilder,
                  isPausedStream: isMeasurePausedStream,
                  captionsAdapter: widget.captionsAdapter,
                  musicDurationStream: _musicDurationStream(
                    measureIndex,
                  ).asBroadcastStream(),
                  isCaptionsVisible: widget.isCaptionsVisible,
                );
              }),
              StreamBuilder(
                stream: _ancStateSubject.where((event) => event.isVisible),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) return const SizedBox.shrink();
                  final isPaused = data.isPaused;
                  return widget.pauseWidgetBuilder?.call(isPaused) ??
                      const SizedBox.shrink();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The base class for widgets that render a specific type of [Measure].
///
/// Extend this class when implementing a custom widget for a measure.
/// It provides a strongly-typed [measure] property of type [M].
/// Example:
/// ```dart
/// class MeasureTestWidget extends MeasureBaseWidget<MeasureTest> {
///   const MeasureTestWidget({super.key, required super.measure});
///
///   @override
///   MeasureBaseState<MeasureBaseWidget<MeasureTest>> createState() {
///     return _MeasureTestWidgetState();
///   }
/// }
/// ```
///
abstract class MeasureBaseWidget<M extends Measure> extends StatefulWidget {
  /// const constructor
  const MeasureBaseWidget({required this.measure, super.key});

  /// The measure instance associated with this widget.
  final M measure;

  @override
  MeasureBaseState<M, MeasureBaseWidget<M>> createState();
}

/// Base state class for widgets extending [MeasureBaseWidget].
///
/// This class provides the core logic for managing a measure's lifecycle,
/// including handling pause/play states, completion, and providing access
/// to the measure's data.
///
/// When extending this class, you must implement [prepareBeforeReady] and
/// [onPause]/[onPlay]. If you use [MeasureCompletionType.custom], you must
/// also override [resolveCompletionCustom].
abstract class MeasureBaseState<
  M extends Measure,
  W extends MeasureBaseWidget<M>
>
    extends State<W> {
  late MeasureWidgetProvider _provider;
  MeasureCompletioner? _completioner;
  StreamSubscription<bool>? _isPausedSubscription;
  StreamSubscription<Duration>? _musicDurationStreamSubscription;

  Future<void> _doAfterCompletion() async {
    _provider.onFinished();
    await _isPausedSubscription?.cancel();
    _isPausedSubscription = null;
  }

  void _doOnStart() {
    //todo could await here duration stream emit one time
    _isPausedSubscription = _provider.isPausedStream.listen((event) {
      if (event) return onPause();
      onPlay();
    });
  }

  @mustCallSuper
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = MeasureWidgetProvider.of(context);
    final musicDurationStream = _provider.musicDurationStream;
    _completioner = switch (widget.measure.completionType) {
      MeasureCompletionType.voice => MeasureVoiceCompletioner(
        completedStream: _provider.voiceCompletedStream,
      ),
      MeasureCompletionType.music => MeasureMusicCompletioner(
        durationStream: musicDurationStream,
      ),
      MeasureCompletionType.custom => null,
    };
    unawaited(prepareBeforeReady().then((_) => _provider.onReady()));
    unawaited(resolveCompletion().then((_) => _doAfterCompletion()));
    unawaited(_provider.voiceDurationFuture?.then(onVoiceDurationChanged));
    _provider.controller.addOnStart(_doOnStart);

    _musicDurationStreamSubscription = musicDurationStream
        ?.where((duration) => duration != null)
        .cast<Duration>()
        .listen(onMusicDurationChanged);
  }

  @mustCallSuper
  @override
  void dispose() {
    unawaited(_isPausedSubscription?.cancel());
    _completioner?.dispose();
    unawaited(_musicDurationStreamSubscription?.cancel());
    super.dispose();
  }

  /// Prepares the measure for playback.
  ///
  /// This method is called before the measure is marked as "ready".
  /// You can use it to load any necessary assets or perform setup.
  /// The future should complete when the measure is ready to be started.
  Future<void> prepareBeforeReady();

  /// Determines when the measure is considered finished.
  ///
  /// This method is responsible for awaiting the completion signal based on
  /// the measure's [Measure.completionType].
  Future<void> resolveCompletion() async {
    if (_completioner == null) return resolveCompletionCustom();
    await _completioner?.resolveCompletion();
  }

  /// Defines the custom completion logic for a measure.
  ///
  /// This method must be overridden if the measure's [Measure.completionType]
  /// is set to [MeasureCompletionType.custom]. The returned [Future] should
  /// complete when the measure is considered finished.
  ///
  /// Throws [UnimplementedError] if not overridden.
  Future<void> resolveCompletionCustom() {
    throw UnimplementedError(
      'You selected MeasureCompletionType.custom '
      'but did not override resolveCompletionCustom().',
    );
  }

  /// Called when the anecdote playback is paused.
  ///
  /// Use this method to pause any animations or processes in your measure
  /// widget.
  void onPause();

  /// Called when the anecdote playback is resumed from a paused state.
  ///
  /// Use this method to resume any animations or processes in your measure
  /// widget.
  void onPlay();

  /// Called when the duration of the voice-over is known.
  ///
  /// You can override this method to adapt your UI to the voice-over's length.
  void onVoiceDurationChanged(Duration duration) {
    // Override if UI needs to adapt to voice length.
  }

  /// Called when the duration of the measure's background music is known.
  ///
  /// You can override this method to adapt your UI to the music's length.
  void onMusicDurationChanged(Duration duration) {
    // Override if UI needs to adapt to measure music length.
  }
}

/// Abstract interface for determining when a measure is "finished".
abstract class MeasureCompletioner {
  /// Returns a future that completes when the measure should end.
  Future<void> resolveCompletion();

  /// Cleans up resources.
  void dispose();
}
