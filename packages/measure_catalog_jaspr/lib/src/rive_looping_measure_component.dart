import 'dart:async';
import 'dart:js_interop';
import 'package:anecdotes_jaspr/anecdotes_jaspr.dart';
import 'package:rive_interop/rive_interop.dart';
import 'package:web/web.dart' as web;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:measure_catalog/measure_catalog.dart';

class RiveLoopingMeasureComponent extends StatefulComponent {
  final RiveLoopingMeasure measure;

  RiveLoopingMeasureComponent({super.key, required this.measure});

  @override
  State<RiveLoopingMeasureComponent> createState() =>
      RiveLoopingMeasureComponentState();
}

class RiveLoopingMeasureComponentState
    extends State<RiveLoopingMeasureComponent>
    with MeasureComponent {
  Rive? _riveInstance;

  final _completer = Completer<void>();

  late final String _canvasId =
      'rive-canvas-${DateTime.now().microsecondsSinceEpoch}';

  RiveLoopingMeasure get _measure => component.measure;

  void _onRiveLoaded() {
    _riveInstance?.resizeDrawingSurfaceToCanvas();
    _completer.complete();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => _initRive());
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

  void _initRive() {
    final canvasElement =
        web.document.getElementById(_canvasId) as web.HTMLCanvasElement?;
    if (canvasElement == null) return;
    _riveInstance = Rive(
      RiveOptions(
        //TODO: change
        src: (_measure.riveFileSource as AssetSource).path,
        canvas: canvasElement,
        stateMachines: _measure.stateMachineName,
        artboard: _measure.artboardName,
        onLoad: _onRiveLoaded.toJS,
      ),
    );
  }

  @override
  void dispose() {
    _riveInstance?.cleanup();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Component.element(
      tag: 'canvas',
      id: _canvasId,
      classes: 'rive-canvas',
      styles: Styles(
        width: 100.percent,
        height: 100.percent,
        outline: Outline.unset,
      ),
    );
  }
}
