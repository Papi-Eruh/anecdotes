import 'dart:async';
import 'dart:convert';

import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/logger.dart';
import 'package:anecdotes/src/widgets/anecdote_widget_impl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:heart/heart.dart';
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

/// A base class for adapters that convert raw file content
/// (such as JSON, XML, or plain text) into a list of [Captions].
// ignore: one_member_abstracts
abstract class CaptionsAdapter {
  /// Converts the given [fileContent] into a list of [Captions].
  /// Implementations should parse the provided [fileContent]
  /// and return a list of captions with their corresponding
  /// start and end times.
  List<Captions> fromFileContent(String fileContent);
}

/// Simple JSON implementation of [CaptionsAdapter].
/// When the file content JSON are exactly well formated
/// for [Captions.fromJson].
class JsonCaptionsAdapter implements CaptionsAdapter {
  /// default const constructor
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

/// Controller of [AnecdoteWidget] allowing user
/// to defer the start of the [AnecdoteWidget].
abstract final class AnecdoteWidgetController {
  factory AnecdoteWidgetController() => _AncWidgetController();

  /// true when the controller has been started.
  bool get isStarted;

  //
  //ignore: avoid_setters_without_getters
  set _onStart(VoidCallback callback);

  /// Start anecdote & so its first measure.
  void start();
}

/// Controller of a measure widget.
abstract final class MeasureWidgetController {
  /// Set what's triggering on start
  void addOnStart(VoidCallback? callback);

  /// Start measure
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
    _onStart = _onStart.chain(callback);
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

/// A widget that displays and manages the playback of an anecdote.
///
/// The [AnecdoteWidget] orchestrates multiple [Measure]s, music and
/// voice playback, captions display, and interactivity.
///
/// It is highly customizable through various builders and adapters,
/// allowing you to define how each part of the anecdote is rendered.
class AnecdoteWidget extends StatefulWidget {
  /// base constructor
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

  /// The anecdote to display, which contains a sequence of measures.
  final Anecdote anecdote;

  /// Registry used to resolve the appropriate widget builder
  /// for each [Measure] subtype.
  final MeasureBuilderRegistry measureBuilderRegistry;

  /// Controller allowing external control over the anecdote playback.
  final AnecdoteWidgetController? controller;

  /// The [MusicPlayer] instance responsible for handling background music.
  final MusicPlayer? musicPlayer;

  /// Builder used to create an [AudioPlayer] for measure narration.
  final VoicePlayerBuilder? voicePlayerBuilder;

  /// Adapter used to parse captions from a file or other source.
  ///
  /// Defaults to [JsonCaptionsAdapter].
  final CaptionsAdapter captionsAdapter;

  /// Optional builder to customize how captions are displayed.
  ///
  /// If null, captions will not be displayed.
  /// See [CaptionsWidgetBuilder] for more details.
  final CaptionsWidgetBuilder? captionsWidgetBuilder;

  /// Optional builder to customize the widget shown when playback is paused.
  final PauseWidgetBuilder? pauseWidgetBuilder;

  /// Called when the first [Measure] is ready to be displayed.
  final VoidCallback? onReady;

  /// Called when the anecdote playback finishes.
  final VoidCallback? onFinished;

  /// Whether the anecdote should loop after finishing.
  final bool loop;

  /// Whether the user can interact with the anecdote.
  final bool isInteractive;

  /// Defines how the music should behave across measures.
  final AncMusicBehavior musicBehavior;

  /// If true, the device screen will stay awake.
  final bool isWakelockedManaged;

  /// If true, show the captions.
  final bool isCaptionsVisible;

  /// The index of [Anecdote.measures] we'll start with.
  /// Default to 0
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
      onTap: ifThen(
        i: widget.isInteractive,
        t: () => _ancStateSubject.add(_ancStateSubject.value.next),
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
                final onReady = ifThen(
                  i: index == _indexMeasureStart && !_isStarted,
                  t: widget.onReady.chain(
                    ifThen(i: _controller == null, t: _start),
                  ),
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
/// Provides convenient access to the typed measure instance.
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

  /// When this future is completed, this measure is considered as ready.
  /// So, this widget is ready to be started.
  Future<void> prepareBeforeReady();

  /// When this future is completed, the measure is considered as finished.
  /// This will lead to go next measure or finish the anecdote.
  Future<void> resolveCompletion() async {
    if (_completioner == null) return resolveCompletionCustom();
    await _completioner?.resolveCompletion();
  }

  /// Override this if your measure uses [MeasureCompletionType.custom].
  ///
  /// You should return a Future that completes when the slide is finished.
  Future<void> resolveCompletionCustom() {
    throw UnimplementedError(
      'You selected MeasureCompletionType.custom '
      'but did not override resolveCompletionCustom().',
    );
  }

  /// Called when playback is paused.
  void onPause();

  /// Called when playback is resumed.
  void onPlay();

  /// Called when the voice-over duration is known.
  void onVoiceDurationChanged(Duration duration) {
    // Override if UI needs to adapt to voice length.
  }

  /// Called when the measure music duration is known.
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
