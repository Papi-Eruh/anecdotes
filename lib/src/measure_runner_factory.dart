import 'package:anecdotes/src/internals/anecdote_context.dart';
import 'package:anecdotes/src/measure_runner.dart';
import 'package:anecdotes/src/models/measure.dart';

abstract interface class MeasureRunnerFactory {
  MeasureRunner createRunner(AnecdoteContext context, Measure measure);
}
