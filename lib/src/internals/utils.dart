import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// Logger for anecdotes package
final ancLogger = Logger('anecdotes');

/// Signature of callbacks that have no arguments and return no data.
typedef VoidCallback = void Function();

typedef Json = Map<String, dynamic>;

extension ToMapIterableExtension<E> on Iterable<E> {
  Map<E, T> toMapItemKey<T>(T Function(E e) toValue) {
    return Map.fromEntries(map((e) => MapEntry(e, toValue(e))));
  }
}

extension BoolExtension on bool {
  /// Retourne [value] si true, sinon null.
  /// (Version Eager - pour valeurs simples)
  T? then<T>(T value) => this ? value : null;

  /// Retourne le résultat de [provider] si true, sinon null.
  /// (Version Lazy - pour calculs ou objets complexes)
  T? thenDo<T>(T Function() provider) => this ? provider() : null;
}

extension ChainingCallback on VoidCallback? {
  /// Chain this with another [callback].
  /// Returns null if both are null (preserving disabled states in UI).
  VoidCallback? then(VoidCallback? callback) {
    if (this == null && callback == null) return null;

    return () {
      this?.call();
      callback?.call();
    };
  }
}

/// Provides utilities for conditionally switching between streams.
///
/// Adds [whenTrueSwitchTo], which allows reacting to another stream
/// only when the current boolean stream emits `true`.
extension ConditionalSwitchMap on Stream<bool> {
  /// Switches to [other] when this stream emits `true`.
  ///
  /// When the latest value emitted by this boolean stream is `true`,
  /// the resulting stream mirrors [other].
  /// When it's `false`, the resulting stream stays silent (emits nothing).
  ///
  /// Example:
  /// ```dart
  /// final isVisibleStream = Stream<bool>.fromIterable([false, true, false]);
  /// final dataStream = Stream<String>.periodic(Duration(seconds: 1), (_) => 'tick');
  ///
  /// final visibleDataStream = isVisibleStream.whenTrueSwitchTo(dataStream);
  ///
  /// visibleDataStream.listen(print); // prints 'tick' only while isVisible is true
  /// ```
  ///
  /// This is particularly useful for UI state management, where a child
  /// widget should only react to another stream while a certain condition holds.
  Stream<T> whenTrueSwitchTo<T>(Stream<T> other) {
    return switchMap((isTrue) => isTrue ? other : const Stream.empty());
  }
}
