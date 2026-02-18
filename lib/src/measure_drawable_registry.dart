import 'package:anecdotes/src/models/measure.dart';

typedef MeasureDrawableBuilder<M extends Measure, Drawable> =
    Drawable Function(M measure);

abstract class MeasureDrawableRegistry<Drawable> {
  void register<M extends Measure>(
    MeasureDrawableBuilder<M, Drawable> toDrawable,
  );
  Drawable build(Measure measure);
}
