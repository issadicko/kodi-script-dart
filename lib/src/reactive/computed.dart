import 'rx.dart';
import 'rx_notifier.dart';
import '../interpreter/interpreter.dart';

/// A computed value that automatically recalculates when dependencies change.
///
/// Usage in KodiScript:
/// ```
/// let a = Obs(5)
/// let b = Obs(10)
/// let sum = Computed(fn() { return a.value + b.value })
/// print(sum.value)  // 15
/// a.set(7)
/// print(sum.value)  // 17 (automatically recalculated)
/// ```
class Computed implements Rx<Object?>, KodiBindable, KodiAssignable {
  final Object? Function() _computeFn;
  
  Object? _cachedValue;
  bool _isDirty = true;
  final Set<Rx> _dependencies = {};
  final List<void Function()> _listeners = [];

  Computed(this._computeFn);

  @override
  Object? get value {
    // Track this Computed in the current capture context (for nested Computed)
    RxNotifier.instance.captureDependency(this);
    
    if (_isDirty) {
      _recalculate();
    }
    return _cachedValue;
  }

  void _recalculate() {
    // Capture dependencies during computation
    RxNotifier.instance.startCapture();
    
    try {
      _cachedValue = _computeFn();
      _isDirty = false;
    } finally {
      final newDeps = RxNotifier.instance.stopCapture();
      _updateDependencies(newDeps.cast<Rx>());
    }
  }

  void _updateDependencies(Set<Rx> newDeps) {
    // Remove listeners from old dependencies
    for (final dep in _dependencies) {
      if (!newDeps.contains(dep)) {
        dep.removeListener(_onDependencyChanged);
      }
    }
    // Add listeners to new dependencies
    for (final dep in newDeps) {
      if (!_dependencies.contains(dep)) {
        dep.addListener(_onDependencyChanged);
      }
    }
    _dependencies.clear();
    _dependencies.addAll(newDeps);
  }

  void _onDependencyChanged() {
    if (!_isDirty) {
      _isDirty = true;
      notifyListeners();
    }
  }

  @override
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    for (final listener in List.from(_listeners)) {
      listener();
    }
  }
  
  @override
  void clearListeners() {
    _listeners.clear();
  }
  
  @override
  int get listenerCount => _listeners.length;
  
  @override
  set value(Object? newValue) {
    // Computed values are read-only
    throw UnsupportedError('Cannot set value on a Computed. Use Obs instead.');
  }
  
  // ============ KodiAssignable Implementation ============

  @override
  void assign(Object? newValue) {
    // Computed values are read-only. We throw to prevent
    // accidental overwriting of the computed variable.
    throw UnsupportedError('Cannot assign to a Computed variable.');
  }

  /// Disposes this Computed, removing all dependency listeners.
  void dispose() {
    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }
    _dependencies.clear();
    _listeners.clear();
  }

  // KodiBindable implementation
  @override
  Object? getProperty(String name) {
    if (name == 'value') return value;
    return null;
  }

  @override
  Object? callMethod(String name, List<Object?> args) {
    // Computed is read-only, no set method
    return methodNotFound;
  }

  @override
  String toString() => 'Computed($_cachedValue)';
}
