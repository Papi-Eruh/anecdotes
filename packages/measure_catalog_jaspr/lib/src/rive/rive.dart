import 'dart:js_interop';

// --- Définitions d'Interopérabilité JS ---

/// Mappe la classe JavaScript 'rive.Rive'
@JS('rive.Rive')
extension type Rive._(JSObject _) implements JSObject {
  /// Constructeur correspondant à : new rive.Rive(options)
  external Rive(RiveOptions options);

  external void play();
  external void pause();
  external void stop();
  external void cleanup();
}

/// Options de configuration pour l'objet Rive
@JS()
@anonymous
extension type RiveOptions._(JSObject _) implements JSObject {
  external factory RiveOptions({
    JSObject canvas,
    JSArrayBuffer? buffer,
    String? src,
    bool autoplay,
    String? stateMachines,
    String? artboard,
  });
}
