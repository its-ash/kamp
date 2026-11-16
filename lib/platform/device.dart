import 'package:flutter/services.dart';

/// Native helpers (`MainActivity.kt`).
class Device {
  const Device();

  static const _channel = MethodChannel('com.itsash.kamp/device');

  /// Keeps the screen on while measuring. Errors are ignored (tests, other OS).
  Future<void> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } on PlatformException {
      // Ignore.
    } on MissingPluginException {
      // Ignore.
    }
  }
}
