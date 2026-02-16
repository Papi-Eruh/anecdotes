import 'package:anecdotes/src/measure_drawable_registry.dart';
import 'package:anecdotes/src/models/measure.dart';

class MeasureDrawableRegistryImpl<Drawable>
    implements MeasureDrawableRegistry<Drawable> {
  final _delegate = <Type, MeasureDrawableBuilder<Drawable>>{};

  @override
  void register<M extends Measure>(
    MeasureDrawableBuilder<Drawable> toDrawable,
  ) {
    _delegate[M] = (measure) {
      if (measure is! M) throw ArgumentError('Wrong register $M');
      return toDrawable(measure);
    };
  }

  @override
  Drawable build(Measure measure) {
    final type = measure.runtimeType;
    final builder = _delegate[type];
    if (builder == null) {
      throw StateError('No builder is associated to type: $type');
    }
    return builder(measure);
  }
}
