import '../interpreter/interpreter.dart';
import 'rx_notifier.dart';
import 'rx.dart';

/// A reactive list that notifies listeners when its content changes.
///
/// Implements [KodiBindable] to expose list methods to KodiScript.
class RxList<E> extends Rx<List<E>> implements KodiBindable {
  RxList([List<E>? initial]) : super(initial ?? []);

  // -- List Methods exposed to Script --

  @override
  Object? getProperty(String name) {
    // 1. Array Properties
    switch (name) {
      case 'length':
      case 'size':
        RxNotifier.instance.captureDependency(this);
        return value.length;
      case 'isEmpty':
        RxNotifier.instance.captureDependency(this);
        return value.isEmpty;
      case 'isNotEmpty':
        RxNotifier.instance.captureDependency(this);
        return value.isNotEmpty;
      case 'first':
        RxNotifier.instance.captureDependency(this);
        return value.isNotEmpty ? value.first : null;
      case 'last':
        RxNotifier.instance.captureDependency(this);
        return value.isNotEmpty ? value.last : null;
      
      // 2. Fallback to base Rx properties (like .value)
      default:
        return super.getProperty(name);
    }
  }

  @override
  Object? callMethod(String name, List<Object?> args) {
    switch (name) {
      // -- Mutation Methods (Trigger Updates) --
      
      case 'add':
        if (args.isNotEmpty) {
          value.add(args[0] as E);
          notifyListeners(); // Force update
          return true;
        }
        return false;

      case 'addAll':
        if (args.isNotEmpty && args[0] is List) {
          value.addAll((args[0] as List).cast<E>());
          notifyListeners();
          return true;
        }
        return false;

      case 'remove':
        if (args.isNotEmpty) {
          final result = value.remove(args[0]);
          if (result) notifyListeners();
          return result;
        }
        return false;

      case 'removeAt':
        if (args.isNotEmpty && args[0] is num) {
          final index = (args[0] as num).toInt();
          if (index >= 0 && index < value.length) {
            final removed = value.removeAt(index);
            notifyListeners();
            return removed;
          }
        }
        return null;

      case 'clear':
        if (value.isNotEmpty) {
          value.clear();
          notifyListeners();
        }
        return null;

      case 'insert':
        if (args.length >= 2 && args[0] is num) {
          final index = (args[0] as num).toInt();
          if (index >= 0 && index <= value.length) {
            value.insert(index, args[1] as E);
            notifyListeners();
          }
        }
        return null;

      // -- Query Methods (Read-only) --

      case 'contains':
        RxNotifier.instance.captureDependency(this);
        return args.isNotEmpty && value.contains(args[0]);

      case 'indexOf':
        RxNotifier.instance.captureDependency(this);
        return args.isNotEmpty ? value.indexOf(args[0] as E) : -1;

      case 'sublist':
      case 'slice':
        RxNotifier.instance.captureDependency(this);
        if (args.isNotEmpty && args[0] is num) {
          final start = (args[0] as num).toInt().clamp(0, value.length);
          final end = (args.length > 1 && args[1] is num) 
              ? (args[1] as num).toInt().clamp(start, value.length) 
              : value.length;
          return value.sublist(start, end);
        }
        return List.from(value); // Clone

      // -- Higher Order Methods --

      case 'map':
        RxNotifier.instance.captureDependency(this);
        if (args.isNotEmpty && args[0] is Function) {
          final fn = args[0] as Function;
          return value.map((e) => fn(e)).toList();
        }
        return []; // Or copy

      case 'filter':
      case 'where':
        RxNotifier.instance.captureDependency(this);
        if (args.isNotEmpty && args[0] is Function) {
          final fn = args[0] as Function;
          return value.where((e) => fn(e) == true).toList();
        }
        return [];

      case 'forEach':
        RxNotifier.instance.captureDependency(this);
        if (args.isNotEmpty && args[0] is Function) {
          final fn = args[0] as Function;
          value.forEach((e) => fn(e));
        }
        return null;

      case 'any':
        RxNotifier.instance.captureDependency(this);
        if (args.isNotEmpty && args[0] is Function) {
          final fn = args[0] as Function;
          return value.any((e) => fn(e) == true);
        }
        return false;

      case 'every':
        RxNotifier.instance.captureDependency(this);
        if (args.isNotEmpty && args[0] is Function) {
          final fn = args[0] as Function;
          return value.every((e) => fn(e) == true);
        }
        return true;

      // Fallback
      default:
        return super.callMethod(name, args);
    }
  }
}

/// Factory function to create RxList from KodiScript.
RxList<Object?> createRxList(List<Object?> args) {
  if (args.isNotEmpty && args[0] is List) {
    return RxList<Object?>(List.from(args[0] as List));
  }
  return RxList<Object?>();
}
