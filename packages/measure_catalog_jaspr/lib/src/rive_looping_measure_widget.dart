import 'dart:async';
import 'dart:js_interop';
import 'package:measure_catalog_jaspr/src/rive/rive.dart';
import 'package:web/web.dart' as web;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:measure_catalog/measure_catalog.dart';

class RiveLoopingMeasureWidget extends StatefulComponent {
  final RiveLoopingRunner runner;

  RiveLoopingMeasureWidget({super.key, required this.runner});

  @override
  State<RiveLoopingMeasureWidget> createState() =>
      RiveLoopingMeasureWidgetState();
}

class RiveLoopingMeasureWidgetState extends State<RiveLoopingMeasureWidget> {
  StreamSubscription? _subscription;
  Rive? _riveInstance;

  late final String _canvasId =
      'rive-canvas-${DateTime.now().microsecondsSinceEpoch}';

  RiveLoopingRunner get _runner => component.runner;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initRive());
    _subscription = _runner.isPlayingStream.listen((isPlaying) {
      if (isPlaying) {
        _riveInstance?.play();
      } else {
        _riveInstance?.pause();
      }
    });
  }

  void _initRive() {
    final canvasElement =
        web.document.getElementById(_canvasId) as web.HTMLCanvasElement?;
    final bytes = _runner.riveBytes;
    if (canvasElement != null && bytes != null) {
      try {
        _riveInstance = Rive(
          RiveOptions(
            canvas: canvasElement,
            buffer: bytes.buffer.toJS,
            autoplay: true,
            stateMachines: _runner.measure.stateMachineName,
            artboard: _runner.measure.artboardName,
          ),
        );
      } catch (e) {
        print('Erreur lors de l\'initialisation de Rive JS: $e');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _riveInstance?.cleanup();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'rive-container', [
      Component.element(
        tag: 'canvas',
        id: _canvasId,
        classes: 'rive-canvas',
        styles: Styles(
          width: 100.percent,
          height: 100.percent,
          outline: Outline.unset,
        ),
      ),
    ]);
  }
}
