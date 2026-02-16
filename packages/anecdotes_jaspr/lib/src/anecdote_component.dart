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
  void initState() {
    super.initState();
    _engine.load(component.anecdote);
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return StreamBuilder(
      stream: _engine.stateStream.map((state) => state.status).distinct(),
      builder: (context, snapshot) {
        final status = snapshot.data;

        if (status == null) {
          return div(classes: 'anecdote-loader', [text('Loading Engine...')]);
        }

        if (status == AnecdoteStatus.initializing) {
          return div(classes: 'anecdote-initializing', [
            text('Preparing Anecdote...'),
          ]);
        }

        return div(
          classes: 'anecdote-container',
          styles: Styles(
            position: Position.relative(),
            width: 100.percent,
            height: 100.percent,
            overflow: Overflow.hidden,
            cursor: Cursor.pointer,
          ),
          events: events(
            onClick: () {
              if (status == AnecdoteStatus.playing) {
                _engine.pause();
              } else {
                _engine.play();
              }
            },
          ),
          [
            StreamBuilder(
              stream: _engine.stateStream
                  .map((state) => (state.measureIndex, state.anecdote))
                  .distinct(),
              builder: (context, snapshot) {
                final data = snapshot.data!;
                final (currentIndex, anecdote) = data;
                final measuresCount = anecdote?.measures.length ?? 0;

                final indicesToRender = [
                  currentIndex - 1,
                  currentIndex,
                  currentIndex + 1,
                ].where((int i) => i >= 0 && i < measuresCount);

                return div(
                  styles: Styles(width: 100.percent, height: 100.percent),
                  [
                    ...indicesToRender.map((index) {
                      final measure = anecdote!.measures[index];
                      return MeasureWrapperWidget(
                        key: ValueKey('measure-$index'),
                        isVisible: index == currentIndex,
                        onReady: () => _engine.notifyReady(index),
                        isPausedStream: _isPausedStream,
                        child: component.registry.build(measure),
                      );
                    }),
                  ],
                );
              },
            ),
            StreamBuilder(
              stream: _engine.stateStream
                  .map((state) => state.captions)
                  .distinct(),
              builder: (context, snapshot) {
                final captions = snapshot.data;
                if (captions == null || captions.isEmpty) {
                  return div([]);
                }
                return div(classes: 'anecdote-captions', [text(captions)]);
              },
            ),
          ],
        );
      },
    );
  }
}

class MeasureWrapperWidget extends StatelessComponent {
  final bool isVisible;
  final VoidCallback onReady;
  final Stream<bool> isPausedStream;
  final Component child;

  MeasureWrapperWidget({
    super.key,
    required this.isVisible,
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
