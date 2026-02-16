import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes_jaspr/src/measure_inherited_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class AnecdoteComponent extends StatefulComponent {
  final Anecdote anecdote;
  final MeasureDrawableRegistry<Component> registry;

  AnecdoteComponent({
    super.key,
    required this.anecdote,
    required this.registry,
  });

  @override
  State<StatefulComponent> createState() {
    return AnecdoteComponentState();
  }
}

class AnecdoteComponentState extends State<AnecdoteComponent> {
  final _engine = createEngine();
  late final _isPausedStream = _engine.stateStream
      .map((state) => state.status)
      .where(
        (status) =>
            status == AnecdoteStatus.paused || status == AnecdoteStatus.playing,
      )
      .map((status) => status == AnecdoteStatus.paused);

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return StreamBuilder(
      stream: _engine.stateStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return div(classes: 'anecdote-loader', [
            Component.text('Loading Engine...'),
          ]);
        }

        final state = snapshot.data!;

        if (state.status == AnecdoteStatus.initializing) {
          return div(classes: 'anecdote-initializing', [
            Component.text('Preparing Anecdote...'),
          ]);
        }

        final currentIndex = state.measureIndex;
        final measuresCount = state.anecdote?.measures.length ?? 0;

        final indicesToRender = [
          currentIndex - 1,
          currentIndex,
          currentIndex + 1,
        ].where((int i) => i >= 0 && i < measuresCount);

        return div(
          classes: 'anecdote-container',
          styles: Styles(
            position: Position.relative(),
            width: 100.percent,
            height: 100.percent,
            overflow: Overflow.hidden,
          ),
          [
            ...indicesToRender.map((index) {
              final measure = state.anecdote!.measures[index];
              return MeasureWrapperWidget(
                isVisible: index == currentIndex,
                measure: measure,
                onReady: () => _engine.notifyReady(index),
                isPausedStream: _isPausedStream,
                child: component.registry.build(measure),
              );
            }),
            if (state.captions != null && state.captions!.isNotEmpty)
              div(classes: 'anecdote-captions', [
                Component.text(state.captions!),
              ]),
          ],
        );
      },
    );
  }
}

class MeasureWrapperWidget extends StatelessComponent {
  final bool isVisible;
  final Measure measure;
  final VoidCallback onReady;
  final Stream<bool> isPausedStream;
  final Component child;

  MeasureWrapperWidget({
    super.key,
    required this.isVisible,
    required this.measure,
    required this.onReady,
    required this.isPausedStream,
    required this.child,
  });

  @override
  Component build(BuildContext context) {
    return div([
      MeasureInheritedComponent(
        isPausedStream: isPausedStream,
        onReady: onReady,
        child: child,
      ),
    ], styles: Styles(display: isVisible ? Display.block : Display.none));
  }
}
