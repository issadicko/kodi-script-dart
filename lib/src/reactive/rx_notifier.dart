/// Singleton manager for reactive dependency capture.
///
/// Used by [Rx] to track which reactive variables are accessed
/// during a build phase, enabling fine-grained reactivity.
class RxNotifier {
  /// Singleton instance.
  static final RxNotifier instance = RxNotifier._();

  RxNotifier._();

  /// Stack of capturers for nested Obx support.
  final List<Set<Object>> _captureStack = [];

  /// Starts capturing reactive dependencies.
  ///
  /// Call this before executing a builder function to track
  /// which Rx variables are accessed. Supports nesting.
  void startCapture() {
    _captureStack.add(<Object>{});
  }

  /// Stops capturing and returns all captured dependencies.
  ///
  /// Returns the set of [Rx] instances that were accessed
  /// since [startCapture] was called. Pops from the stack.
  Set<Object> stopCapture() {
    if (_captureStack.isEmpty) {
      return <Object>{};
    }
    return _captureStack.removeLast();
  }

  /// Registers an Rx as a dependency if capture is active.
  ///
  /// Called internally by [Rx.value] getter. Adds to the CURRENT capturer only.
  void captureDependency(Object rx) {
    if (_captureStack.isNotEmpty) {
      _captureStack.last.add(rx);
    }
  }

  /// Whether dependency capture is currently active.
  bool get isCapturing => _captureStack.isNotEmpty;

  /// Clears the current capture without returning dependencies.
  void cancelCapture() {
    if (_captureStack.isNotEmpty) {
      _captureStack.removeLast();
    }
  }
}

