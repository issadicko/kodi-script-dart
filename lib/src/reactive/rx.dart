import '../interpreter/interpreter.dart';
import 'rx_notifier.dart';

/// A reactive variable that notifies listeners when its value changes.
///
/// Implements [KodiBindable] to be usable directly from KodiScript.
///
/// Usage from KodiScript:
/// ```
/// var counter = Obs(0)
/// counter.value        // Get the value
/// counter.set(5)       // Set the value
/// counter.update(fn)   // Update via function
/// ```
class Rx<T> implements KodiBindable {
  T _value;
  final List<void Function()> _listeners = [];

  /// Creates a reactive variable with an initial value.
  Rx(this._value);

  /// Gets the current value.
  ///
  /// If [RxNotifier] is capturing dependencies, this Rx
  /// will be registered as a dependency.
  T get value {
    RxNotifier.instance.captureDependency(this);
    return _value;
  }

  /// Sets a new value and notifies listeners if changed.
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      _notifyListeners();
    }
  }

  /// Adds a listener that will be called when the value changes.
  void addListener(void Function() listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Removes a previously added listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Removes all listeners.
  void clearListeners() {
    _listeners.clear();
  }

  /// Returns the number of active listeners.
  int get listenerCount => _listeners.length;

  void _notifyListeners() {
    // Create a copy to avoid concurrent modification
    final listenersCopy = List<void Function()>.from(_listeners);
    for (final listener in listenersCopy) {
      listener();
    }
  }

  // ============ KodiBindable Implementation ============

  @override
  Object? getProperty(String name) {
    switch (name) {
      case 'value':
        // Capture dependency when accessed from script
        RxNotifier.instance.captureDependency(this);
        return _value;
      default:
        return null;
    }
  }

  @override
  Object? callMethod(String name, List<Object?> args) {
    switch (name) {
      case 'set':
        if (args.isNotEmpty) {
          value = args[0] as T;
        }
        return null;

      case 'update':
        // Update via a function: counter.update(fn(v) { return v + 1 })
        if (args.isNotEmpty) {
          final fn = args[0];
          if (fn is Function) {
            value = fn(_value) as T;
          }
        }
        return null;

      case 'toggle':
        // Special case for boolean Rx
        if (_value is bool) {
          value = (!(_value as bool)) as T;
        }
        return null;

      default:
        return methodNotFound;
    }
  }

  @override
  String toString() => 'Rx($_value)';
}

/// Factory function to create Rx instances from KodiScript.
///
/// This function is registered as 'Obs' in the native functions.
Rx<Object?> createObs(List<Object?> args) {
  return Rx<Object?>(args.isNotEmpty ? args[0] : null);
}
