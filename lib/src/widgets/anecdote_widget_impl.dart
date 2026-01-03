import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/internals/internals.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class MeasureDecoratorWidget extends StatefulWidget {
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

  final Measure measure;
  final MeasureBuilderRegistry registry;
  final VoidCallback? onReady;
  final VoidCallback onFinished;
  final MeasureWidgetController controller;
  final CaptionsWidgetBuilder? captionsWidgetBuilder;
  final CaptionsAdapter captionsAdapter;
  final VoicePlayerBuilder? voicePlayerBuilder;
  final Stream<bool> isPausedStream;
  final Stream<Duration?>? musicDurationStream;
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

class MeasureWidgetProvider extends InheritedWidget {
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

  final VoidCallback onReady;
  final VoidCallback onFinished;
  final Stream<bool> isPausedStream;
  final MeasureWidgetController controller;
  final Stream<void>? voiceCompletedStream;
  final Future<Duration>? voiceDurationFuture;
  final Stream<Duration?>? musicDurationStream;

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

/// Helper class to mutualize logic of our measure completion mixins.
class MeasureStreamCompletionHelper {
  /// constructor
  MeasureStreamCompletionHelper(this.stream);

  /// Completion stream
  final Stream<void>? stream;

  StreamSubscription<void>? _sub;

  /// Returns a future once the stream has first emitted.
  Future<void> resolveCompletion() {
    final completer = Completer<void>();
    _sub = stream?.listen((_) {
      completer.complete();
      unawaited(_sub?.cancel());
    });
    return completer.future;
  }

  /// Dispose allocated resources from this.
  void dispose() => unawaited(_sub?.cancel());
}

abstract class CaptionsStreamController {
  Stream<String?> get stream;

  Future<void> load();

  Future<void> close();

  Future<void> start();

  Future<void> pause();

  Future<void> resume();
}

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
