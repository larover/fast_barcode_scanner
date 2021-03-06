import 'dart:async';
import 'dart:ui';

import 'package:fast_barcode_scanner/src/camera_state.dart';
import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final ErrorCallback _defaultOnError = (BuildContext context, Object error) {
  debugPrint("Error reading from camera: $error");
  return Center(child: Text("Error reading from camera..."));
};

typedef Widget ErrorCallback(BuildContext context, Object error);

/// The main class connecting the platform code to the Flutter UI.
///
/// This class is used in a widget tree and connects to the camera
/// as soon as the build method gets called.
class BarcodeCamera extends StatefulWidget {
  BarcodeCamera(
      {Key key,
      @required this.types,
      @required this.onDetect,
      this.mode = DetectionMode.pauseVideo,
      this.resolution = Resolution.hd720,
      this.framerate = Framerate.fps60,
      this.child,
      ErrorCallback onError})
      : onError = onError ?? _defaultOnError,
        super(key: key);

  final List<BarcodeType> types;
  final void Function(Barcode) onDetect;
  final Resolution resolution;
  final Framerate framerate;
  final DetectionMode mode;
  final Widget child;
  final ErrorCallback onError;

  @override
  BarcodeCameraState createState() => BarcodeCameraState();
}

class BarcodeCameraState extends State<BarcodeCamera> {
  Future<void> _init;
  PreviewConfiguration _previewConfig;
  Object _error;
  double _opacity = 0.0;
  Future<bool> _togglingTorch;
  final _eventNotifier = ValueNotifier(CameraEvent.init);

  FastBarcodeScannerPlatform get _platform =>
      FastBarcodeScannerPlatform.instance;

  @override
  void initState() {
    super.initState();
    _initDetector();
  }

  /// Informs the platform to initialize the camera.
  ///
  /// The camera is initialized only once per session.
  /// All susequent calls to this method will be dropped.
  void _initDetector() async {
    if (_init != null) return;

    _init = _platform
        .init(widget.types, widget.resolution, widget.framerate, widget.mode)
        .then((value) => _previewConfig = value)
        .catchError((error) => setState(() => _error = error))
        .whenComplete(() => setState(() => _opacity = 1.0));

    /// Notify the overlays when a barcode is detected and then call [onDetect].
    _platform.setOnDetectHandler((code) {
      _eventNotifier.value = CameraEvent.codeFound;
      widget.onDetect(code);
    });
  }

  Future<void> pauseDetector() {
    _eventNotifier.value = CameraEvent.paused;
    return _platform.pause();
  }

  Future<void> resumeDetector() {
    _eventNotifier.value = CameraEvent.resumed;
    return _platform.resume();
  }

  @override
  dispose() {
    _platform.dispose();
    super.dispose();
  }

  Future<bool> toggleTorch() async {
    if (_togglingTorch == null)
      _togglingTorch =
          _platform.toggleTorch().whenComplete(() => _togglingTorch = null);
    return _togglingTorch;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 260),
        child: Stack(fit: StackFit.expand, children: [
          if (_error != null) widget.onError(context, _error),
          if (_previewConfig != null) _buildPreview(_previewConfig),
          if (widget.child != null) _buildOverlay()
        ]),
      ),
    );
  }

  Widget _buildOverlay() {
    return ValueListenableBuilder(
      valueListenable: _eventNotifier,
      builder: (context, state, _) => CameraState(
        event: state,
        child: widget.child,
      ),
    );
  }

  Widget _buildPreview(PreviewConfiguration details) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: details.width.toDouble(),
        height: details.height.toDouble(),
        child: Texture(
          textureId: details.textureId,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
