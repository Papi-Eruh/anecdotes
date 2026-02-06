import 'dart:async';

import 'package:anecdotes/anecdotes.dart';

class CaptionsControllerImpl implements CaptionsController {
  final AudioPlayer _voicePlayer;
  final StreamController<String?> _textController =
      StreamController<String?>.broadcast();

  StreamSubscription<Duration>? _positionSubscription;

  var _captions = <Caption>[];
  int _currentIndex = 0;
  String? _lastEmittedText;
  Duration _lastPosition = Duration.zero;

  CaptionsControllerImpl({required AudioPlayer voicePlayer})
    : _voicePlayer = voicePlayer;

  @override
  Stream<String?> get textStream => _textController.stream;

  @override
  void start(List<Caption> captions) {
    if (_positionSubscription != null) {
      throw StateError('Controller is already started.');
    }
    _captions = captions;
    _positionSubscription = _voicePlayer.positionStream.listen(
      _onPositionChanged,
    );
  }

  @override
  void play() {
    if (_positionSubscription == null) {
      throw StateError(
        'Controller is not started. You should call start() before.',
      );
    }
    _positionSubscription!.resume();
  }

  @override
  void pause() {
    _positionSubscription?.pause();
  }

  @override
  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _resetState();
    if (!_textController.isClosed) {
      _textController.add(null);
    }
  }

  @override
  void dispose() {
    stop();
    _textController.close();
  }

  void _onPositionChanged(Duration currentPosition) {
    if (currentPosition < _lastPosition) {
      _currentIndex = 0;
    }
    _lastPosition = currentPosition;

    while (_currentIndex < _captions.length &&
        currentPosition >= _captions[_currentIndex].end) {
      _currentIndex++;
    }

    if (_currentIndex >= _captions.length) {
      _emitIfChanged(null);
      return;
    }

    final currentCaption = _captions[_currentIndex];

    if (currentPosition >= currentCaption.start) {
      _emitIfChanged(currentCaption.text);
    } else {
      _emitIfChanged(null);
    }
  }

  void _emitIfChanged(String? text) {
    if (_lastEmittedText != text) {
      _lastEmittedText = text;
      if (!_textController.isClosed) {
        _textController.add(text);
      }
    }
  }

  void _resetState() {
    _currentIndex = 0;
    _lastEmittedText = null;
    _lastPosition = Duration.zero;
  }
}
