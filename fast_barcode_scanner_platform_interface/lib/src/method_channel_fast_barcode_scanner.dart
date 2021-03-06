import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';
import 'fast_barcode_scanner_platform_interface.dart';

class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  static const MethodChannel _channel =
      const MethodChannel('com.jhoogstraat/fast_barcode_scanner');

  void Function(Barcode) _onDetectHandler;

  @override
  void setOnDetectHandler(void Function(Barcode) handler) =>
      _onDetectHandler = handler;

  Future<PreviewConfiguration> init(
      List<BarcodeType> types,
      Resolution resolution,
      Framerate framerate,
      DetectionMode detectionMode) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'read':
          // This might fail if the code type is not present in the list of available code types.
          // Barcode init will throw in this case.
          _onDetectHandler?.call(Barcode(call.arguments));
          break;
        default:
          assert(true,
              "FastBarcodeScanner: unknown method call received: ${call.method}");
      }
    });

    final response = await _channel.invokeMethod('start', {
      'types': types.map((e) => describeEnum(e)).toList(growable: false),
      'mode': describeEnum(detectionMode),
      'res': describeEnum(resolution),
      'fps': describeEnum(framerate)
    });

    return PreviewConfiguration(response);
  }

  Future<void> dispose() {
    _channel.setMethodCallHandler(null);
    _onDetectHandler = null;
    return _channel.invokeMethod('stop');
  }

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> resume() => _channel.invokeMethod('resume');

  Future<bool> toggleTorch() => _channel.invokeMethod('toggleTorch');
}
