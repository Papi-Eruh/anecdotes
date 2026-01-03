import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

/// Logger for anecdotes package
final ancLogger = Logger('anecdotes');

/// Signature of callbacks that have no arguments and return no data.
typedef VoidCallback = void Function();

typedef Json = Map<String, dynamic>;

/// An extension on [Iterable] to add a `toMapItemKey` method.
extension ToMapIterableExtension<E> on Iterable<E> {
  /// Creates a [Map] from an iterable, using the items as keys.
  ///
  /// The [toValue] function is applied to each item to produce the
  /// corresponding value.
  ///
  /// ```dart
  /// final numbers = [1, 2, 3];
  /// final map = numbers.toMapItemKey((i) => i * 2);
  /// print(map); // {1: 2, 2: 4, 3: 6}
  /// ```
  Map<E, T> toMapItemKey<T>(T Function(E e) toValue) {
    return Map.fromEntries(map((e) => MapEntry(e, toValue(e))));
  }
}

/// An extension on [bool] to provide conditional value resolution.
extension BoolExtension on bool {
  /// Returns [value] if this boolean is `true`, otherwise returns `null`.
  ///
  /// This is an eager version, suitable for simple, pre-computed values.
  ///
  /// ```dart
  /// final result = (2 > 1).then('Success'); // 'Success'
  /// final noResult = (1 > 2).then('Failure'); // null
  /// ```
  T? then<T>(T value) => this ? value : null;

  /// Executes [provider] and returns its result if this boolean is `true`,
  /// otherwise returns `null`.
  ///
  /// This is a lazy version, suitable for computations or creating complex
  /// objects, as the [provider] is only called when needed.
  ///
  /// ```dart
  /// final result = (2 > 1).thenDo(() => 'Success'); // 'Success'
  /// final noResult = (1 > 2).thenDo(() => 'Failure'); // null
  /// ```
  T? thenDo<T>(T Function() provider) => this ? provider() : null;
}

/// An extension on [VoidCallback?] to allow chaining callbacks.
extension ChainingCallback on VoidCallback? {
  /// Chains this callback with another [callback].
  ///
  /// Returns a new [VoidCallback] that executes this callback (if it's not
  /// `null`), followed by the other [callback] (if it's not `null`).
  ///
  /// If both callbacks are `null`, this method returns `null`, which is
  /// useful for preserving disabled states in UI components.
  ///
  /// ```dart
  /// VoidCallback? first = () => print('First');
  /// VoidCallback? second = () => print('Second');
  /// final chained = first.then(second);
  /// chained?.call(); // Prints 'First', then 'Second'
  /// ```
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
