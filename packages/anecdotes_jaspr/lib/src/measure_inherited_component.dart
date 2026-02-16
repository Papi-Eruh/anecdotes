import 'dart:async';

import 'package:jaspr/jaspr.dart';

class MeasureInheritedComponent extends InheritedComponent {
  const MeasureInheritedComponent({
    required super.child,
    super.key,
    required this.isPausedStream,
    required this.onReady,
  });

  final Stream<bool> isPausedStream;
  final VoidCallback onReady;

  static MeasureInheritedComponent of(BuildContext context) {
    final result = context
        .dependOnInheritedComponentOfExactType<MeasureInheritedComponent>();
    assert(result != null, 'No MeasureInheritedComponent found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant MeasureInheritedComponent oldComponent) {
    return false;
  }
}
