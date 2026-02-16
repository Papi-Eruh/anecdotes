import 'dart:js_interop';

@JS('rive.EventType')
extension type EventType._(JSObject _) implements JSObject {
  external static String get RiveEvent;
  external static String get Play;
  external static String get Pause;
  external static String get Stop;
  external static String get Loop;
  external static String get Advance;
}

@JS('rive.Rive')
extension type Rive._(JSObject _) implements JSObject {
  external Rive(RiveOptions options);

  external void play();
  external void pause();
  external void stop();

  external void cleanup();

  external void resizeDrawingSurfaceToCanvas();

  external JSArray<StateMachineInput> stateMachineInputs(
    String stateMachineName,
  );

  external void on(String eventType, JSFunction callback);
}

@JS()
@anonymous
extension type RiveOptions._(JSObject _) implements JSObject {
  external factory RiveOptions({
    JSObject? canvas, // Le canvas HTML
    JSArrayBuffer? buffer, // Si tu charges des bytes directement
    String? src, // L'URL du fichier .riv
    bool? autoplay,
    String? stateMachines, // Nom de la State Machine par défaut
    String? artboard, // Nom de l'Artboard (optionnel)
    JSFunction? onLoad, // Callback une fois chargé
  });
}

@JS()
extension type StateMachineInput._(JSObject _) implements JSObject {
  external String get name;

  external void fire();

  external JSAny get value;

  external set value(JSAny value);
}

@JS()
extension type RiveEventPayload._(JSObject _) implements JSObject {
  external RiveEventData get data;
}

@JS()
extension type RiveEventData._(JSObject _) implements JSObject {
  external String get name;

  external int get type;
}
