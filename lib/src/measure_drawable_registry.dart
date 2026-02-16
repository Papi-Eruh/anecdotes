import 'package:anecdotes/src/models/measure.dart';

typedef MeasureDrawableBuilder<Drawable> = Drawable Function(Measure measure);

abstract class MeasureDrawableRegistry<Drawable> {
  void register<M extends Measure>(MeasureDrawableBuilder<Drawable> toDrawable);
  Drawable build(Measure measure);
}
