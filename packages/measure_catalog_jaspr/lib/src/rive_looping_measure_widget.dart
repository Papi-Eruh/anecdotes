import 'dart:async';
import 'dart:js_interop';
import 'package:anecdotes_jaspr/anecdotes_jaspr.dart';
import 'package:measure_catalog_jaspr/src/rive/rive.dart';
import 'package:web/web.dart' as web;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:measure_catalog/measure_catalog.dart';

class RiveLoopingMeasureWidget extends StatefulComponent {
  final RiveLoopingMeasure measure;

  RiveLoopingMeasureWidget({super.key, required this.measure});

  @override
  State<RiveLoopingMeasureWidget> createState() =>
      RiveLoopingMeasureWidgetState();
}

class RiveLoopingMeasureWidgetState extends State<RiveLoopingMeasureWidget>
    with MeasureComponent {
  Rive? _riveInstance;

  final _completer = Completer<void>();

  late final String _canvasId =
      'rive-canvas-${DateTime.now().microsecondsSinceEpoch}';

  RiveLoopingMeasure get _measure => component.measure;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => _initRive());
  }

  void _initRive() {
    final canvasElement =
        web.document.getElementById(_canvasId) as web.HTMLCanvasElement?;
    if (canvasElement == null) return;
    try {
      _riveInstance = Rive(
        RiveOptions(
          //TODO: change
          src: (_measure.riveFileSource as AssetSource).path,
          canvas: canvasElement,
          stateMachines: _measure.stateMachineName,
          artboard: _measure.artboardName,
          onLoad: () {
            _riveInstance?.resizeDrawingSurfaceToCanvas();
            _completer.complete();
          }.toJS,
        ),
      );
    } catch (e) {
      print('Erreur lors de l\'initialisation de Rive JS: $e');
    }
  }

  @override
  void dispose() {
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

  @override
  Future<void> notifyReady() {
    return _completer.future;
  }

  @override
  void onPause() {
    _riveInstance?.pause();
  }

  @override
  void onPlay() {
    _riveInstance?.play();
  }
}
