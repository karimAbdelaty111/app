import 'package:flutter/foundation.dart';
import 'package:shake/shake.dart';

/// Detects a physical shake of the device.
///
/// The service owns the accelerometer subscription of the `shake` package, so
/// the caller only has to call [start] once and [dispose] when the screen that
/// uses it is closed.
class ShakeService {
  ShakeService({
    required this.onShake,
    this.shakeThresholdGravity = 2.7,
    this.minimumShakeCount = 2,
    this.shakeSlopTime = const Duration(milliseconds: 600),
    this.shakeCountResetTime = const Duration(seconds: 3),
  });

  /// Called every time a shake gesture is recognized.
  final VoidCallback onShake;

  /// Gravity value the accelerometer has to exceed to count as a shake.
  final double shakeThresholdGravity;

  /// Number of movements needed before [onShake] is called, this keeps a
  /// single movement of the phone from triggering the action.
  final int minimumShakeCount;

  /// Minimum time between two movements of the same shake gesture.
  final Duration shakeSlopTime;

  /// Time after which the movement counter starts again.
  final Duration shakeCountResetTime;

  ShakeDetector? _detector;

  /// Whether the accelerometer is currently observed.
  bool get isListening => _detector != null;

  /// Starts the shake detection.
  ///
  /// Returns `false` when the device does not provide an accelerometer, which
  /// is the case on simulators and on platforms without motion sensors. The
  /// screen then simply does not react to shakes.
  bool start() {
    if (isListening) {
      return true;
    }
    final detector = ShakeDetector.waitForStart(
      onPhoneShake: (_) => onShake(),
      shakeThresholdGravity: shakeThresholdGravity,
      minimumShakeCount: minimumShakeCount,
      shakeSlopTimeMS: shakeSlopTime.inMilliseconds,
      shakeCountResetTime: shakeCountResetTime.inMilliseconds,
    );
    try {
      detector.startListening();
    } catch (error) {
      debugPrint('ShakeService: shake detection is not available - $error');
      return false;
    }
    _detector = detector;
    return true;
  }

  /// Stops the shake detection and cancels the accelerometer subscription.
  void dispose() {
    _detector?.stopListening();
    _detector = null;
  }
}
