/// Singleton manager for reactive dependency capture.
///
/// Used by [Rx] to track which reactive variables are accessed
/// during a build phase, enabling fine-grained reactivity.
class RxNotifier {
  /// Singleton instance.
  static final RxNotifier instance = RxNotifier._();

  RxNotifier._();

  /// Set of Rx instances being captured during the current build.
  Set<Object>? _currentCapturer;

  /// Starts capturing reactive dependencies.
  ///
  /// Call this before executing a builder function to track
  /// which Rx variables are accessed.
  void startCapture() {
    _currentCapturer = <Object>{};
  }

  /// Stops capturing and returns all captured dependencies.
  ///
  /// Returns the set of [Rx] instances that were accessed
  /// since [startCapture] was called.
  Set<Object> stopCapture() {
    final captured = _currentCapturer ?? <Object>{};
    _currentCapturer = null;
    return captured;
  }

  /// Registers an Rx as a dependency if capture is active.
  ///
  /// Called internally by [Rx.value] getter.
  void captureDependency(Object rx) {
    _currentCapturer?.add(rx);
  }

  /// Whether dependency capture is currently active.
  bool get isCapturing => _currentCapturer != null;

  /// Clears the current capture without returning dependencies.
  void cancelCapture() {
    _currentCapturer = null;
  }
}
