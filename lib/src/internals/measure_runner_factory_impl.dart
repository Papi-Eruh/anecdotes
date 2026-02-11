import 'package:anecdotes/src/anecdote_context.dart';
import 'package:anecdotes/src/measure_runner.dart';
import 'package:anecdotes/src/measure_runner_factory.dart';
import 'package:anecdotes/src/models/measure.dart';

typedef MeasureRunnerBuilder =
    MeasureRunner Function(AnecdoteContext context, Measure measure);

class RegistryMeasureRunnerFactory implements MeasureRunnerFactory {
  final Map<Type, MeasureRunnerBuilder> _builderByType = {};

  RegistryMeasureRunnerFactory();

  void register<M extends Measure>(MeasureRunnerBuilder builder) {
    _builderByType[M] = (c, m) => builder(c, m as M);
  }

  @override
  MeasureRunner createRunner(AnecdoteContext context, Measure measure) {
    final builder = _builderByType[measure.runtimeType];
    if (builder == null) {
      throw Exception("No runner registered for ${measure.runtimeType}");
    }
    return builder(context, measure);
  }
}
