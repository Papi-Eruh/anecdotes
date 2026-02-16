import 'dart:async';

import 'package:anecdotes_jaspr/src/measure_inherited_component.dart';
import 'package:jaspr/jaspr.dart';

mixin MeasureComponent<Component extends StatefulComponent>
    on State<Component> {
  StreamSubscription<bool>? _isPausedSubscription;
  @override
  void initState() {
    super.initState();
    final inheritedData = MeasureInheritedComponent.of(context);
    notifyReady().then((_) => inheritedData.onReady());
    _isPausedSubscription = inheritedData.isPausedStream.listen((isPaused) {
      if (isPaused) {
        onPause();
      } else {
        onPlay();
      }
    });
  }

  @override
  void dispose() {
    _isPausedSubscription?.cancel();
    super.dispose();
  }

  Future<void> notifyReady();

  // only called on AnecdoteStatus.play
  void onPlay();
  //only called on AnecdoteStatus.pause
  void onPause();

  Future<void> complete() {
    throw UnimplementedError('complete() should be overriden.');
  }
}
