/// KodiScript Interpreter - Evaluates AST nodes.
library;

import 'dart:developer';

import '../ast/ast.dart';
import '../natives/natives.dart';

/// Sentinel object to indicate that a method was not found.
/// Used to distinguish between a method that returns null and a missing method.
class _MethodNotFound {
  const _MethodNotFound();
}

/// Sentinel value indicating a method was not found on a KodiBindable object.
const methodNotFound = _MethodNotFound();

/// Interface for objects that can be bound to KodiScript.
///
/// Implement this interface on Dart classes you want to expose to
/// KodiScript via the `.bind()` API.
///
/// Example:
/// ```dart
/// class User implements KodiBindable {
///   final String name;
///   User(this.name);
///
///   @override
///   Object? getProperty(String name) {
///     if (name == 'name') return this.name;
///     return null;
///   }
///
///   @override
///   Object? callMethod(String name, List<Object?> args) {
///     if (name == 'sayHello') return "Hello, I'm ${this.name}";
///     return null;
///   }
/// }
/// ```
abstract class KodiBindable {
  /// Get a property value by name.
  /// Returns null if the property doesn't exist.
  Object? getProperty(String name);

  /// Call a method by name with arguments.
  /// Returns [methodNotFound] if the method doesn't exist.
  /// Can return null if the method exists and returns null.
  Object? callMethod(String name, List<Object?> args);
}

/// Environment holds variable bindings.
class Environment {
  final Environment? _outer;
  final Map<String, Object?> _store = {};
  final List<String> _output = [];

  Environment([this._outer]);

  (Object?, bool) get(String name) {
    if (_store.containsKey(name)) {
      return (_store[name], true);
    }
    return _outer?.get(name) ?? (null, false);
  }

  void set(String name, Object? value) {
    _store[name] = value;
  }

  /// Updates a variable in the scope where it was originally defined.
  ///
  /// Searches up the scope chain to find where the variable exists,
  /// then updates it there. If not found, sets it in the current scope.
  bool update(String name, Object? value) {
    if (_store.containsKey(name)) {
      _store[name] = value;
      return true;
    }
    if (_outer != null) {
      return _outer!.update(name, value);
    }
    // Variable not found in any scope, set in current scope
    _store[name] = value;
    return false;
  }

  void addOutput(String line) {
    _output.add(line);
  }

  List<String> getOutput() => List.unmodifiable(_output);

  /// Clears the output buffer.
  void clearOutput() {
    _output.clear();
  }

  /// Exports all variables from all scopes to a Map.
  ///
  /// Variables in inner scopes shadow those in outer scopes.
  Map<String, Object?> toMap() {
    final result = <String, Object?>{};
    // First add outer scope variables (if any)
    if (_outer != null) {
      result.addAll(_outer!.toMap());
    }
    // Then add current scope (shadows outer)
    result.addAll(_store);
    return result;
  }
}

/// Wrapper to signal early return from evaluation.
class ReturnValue {
  final Object? value;
  ReturnValue(this.value);
}

/// Function value (user defined).
class FunctionValue {
  final List<Identifier> parameters;
  final BlockStatement body;
  final Environment env;

  FunctionValue(this.parameters, this.body, this.env);
}

/// Native function wrapper.
class NativeFunctionValue {
  final NativeFunc fn;
  NativeFunctionValue(this.fn);
}

/// Exception thrown when max operations is exceeded.
class MaxOperationsExceeded implements Exception {
  @override
  String toString() => 'max operations exceeded';
}

/// Exception thrown when execution timeout is exceeded.
class TimeoutException implements Exception {
  @override
  String toString() => 'execution timeout';
}

/// Interpreter evaluates AST nodes.
class Interpreter {
  Environment _env;
  final NativeFunctions _natives;
  int _opCount = 0;
  int _maxOps = 0; // 0 = unlimited
  int _deadline = 0; // 0 = no timeout

  Interpreter({Environment? env, NativeFunctions? natives})
      : _env = env ?? Environment(),
        _natives = natives ?? NativeFunctions.shared;

  factory Interpreter.withVariables(Map<String, Object?> variables) {
    final env = Environment();
    variables.forEach((k, v) => env.set(k, v));
    return Interpreter(env: env);
  }

  /// Sets the maximum number of operations allowed.
  /// If maxOps is 0, there is no limit (default).
  void setMaxOperations(int maxOps) {
    _maxOps = maxOps;
    _opCount = 0;
  }

  /// Sets the execution deadline (milliseconds since epoch).
  void setDeadline(int deadline) {
    _deadline = deadline;
  }

  /// Checks the operation limit and throws if exceeded.
  void _checkOperationLimit() {
    if (_maxOps > 0) {
      _opCount++;
      if (_opCount > _maxOps) {
        throw MaxOperationsExceeded();
      }
    }
  }

  /// Checks if the deadline has been exceeded.
  void _checkDeadline() {
    if (_deadline > 0) {
      if (DateTime.now().millisecondsSinceEpoch > _deadline) {
        throw TimeoutException();
      }
    }
  }

  Object? eval(Program program) {
    Object? result;
    for (final stmt in program.statements) {
      result = _evalStatement(stmt);
      if (result is ReturnValue) {
        return result.value;
      }
    }
    return result;
  }

  /// Returns the current environment.
  ///
  /// Used by KSEngine to access the script context.
  Environment get environment => _env;

  /// Calls a user-defined function with the given arguments.
  ///
  /// This is a public wrapper around [_applyFunction] for use by KSEngine.
  Object? callFunction(FunctionValue fn, List<Object?> args) {
    return _applyFunction(fn, args);
  }

  List<String> getOutput() => _env.getOutput();

  /// Clears the output buffer.
  void clearOutput() {
    _env.clearOutput();
  }

  Object? _evalStatement(Statement stmt) {
    // Check operation limit at each statement
    _checkOperationLimit();
    // Check deadline at each statement
    _checkDeadline();

    switch (stmt) {
      case VarDecl():
        final value = _evalExpression(stmt.value);
        _env.set(stmt.name.value, value);
        return value;
      case Assignment():
        final value = _evalExpression(stmt.value);
        // Use update to modify variable in its original scope
        _env.update(stmt.name.value, value);
        return value;
      case ExpressionStatement():
        return _evalExpression(stmt.expression);
      case IfStatement():
        return _evalIfStatement(stmt);
      case BlockStatement():
        return _evalBlockStatement(stmt);
      case ReturnStatement():
        final value = stmt.value != null ? _evalExpression(stmt.value!) : null;
        return ReturnValue(value);
      case ForStatement():
        return _evalForStatement(stmt);
      case WhileStatement():
        return _evalWhileStatement(stmt);
      case FunctionDeclaration():
        final fn = FunctionValue(stmt.parameters, stmt.body, _env);
        _env.set(stmt.name.value, fn);
        return null; // Function declaration statement returns null
    }
  }

  Object? _evalIfStatement(IfStatement stmt) {
    final condition = _evalExpression(stmt.condition);
    if (_isTruthy(condition)) {
      return _evalBlockStatement(stmt.consequence);
    } else if (stmt.alternative != null) {
      return _evalBlockStatement(stmt.alternative!);
    }
    return null;
  }

  Object? _evalForStatement(ForStatement stmt) {
    final iterableVal = _evalExpression(stmt.iterable);

    if (iterableVal is! List) {
      throw Exception(
          'for-in requires an array, got ${iterableVal?.runtimeType}');
    }

    Object? result;
    final varName = stmt.variable.value;

    for (final item in iterableVal) {
      // Check operation limit at each iteration
      _checkOperationLimit();
      // Check deadline at each iteration
      _checkDeadline();

      _env.set(varName, item);
      final value = _evalBlockStatement(stmt.body);
      if (value is ReturnValue) {
        return value;
      }
      result = value;
    }

    return result;
  }

  Object? _evalWhileStatement(WhileStatement stmt) {
    Object? result;

    while (true) {
      // Check operation limit at each iteration
      _checkOperationLimit();
      // Check deadline at each iteration
      _checkDeadline();

      // Evaluate condition
      final conditionValue = _evalExpression(stmt.condition);

      // Exit if condition is false
      if (!_isTruthy(conditionValue)) {
        break;
      }

      // Execute body
      final value = _evalBlockStatement(stmt.body);
      if (value is ReturnValue) {
        return value;
      }
      result = value;
    }

    return result;
  }

  Object? _evalBlockStatement(BlockStatement block) {
    Object? result;
    for (final stmt in block.statements) {
      result = _evalStatement(stmt);
      if (result is ReturnValue) {
        return result;
      }
    }
    return result;
  }

  String _evalStringTemplate(StringTemplate tmpl) {
    final buffer = StringBuffer();
    for (final part in tmpl.parts) {
      final value = _evalExpression(part);
      if (value == null) {
        buffer.write('null');
      } else {
        buffer.write(value.toString());
      }
    }
    return buffer.toString();
  }

  Object? _evalExpression(Expression expr) {
    switch (expr) {
      case NumberLiteral():
        return expr.value;
      case StringLiteral():
        return expr.value;
      case StringTemplate():
        return _evalStringTemplate(expr);
      case BooleanLiteral():
        return expr.value;
      case NullLiteral():
        return null;
      case Identifier():
        final (value, found) = _env.get(expr.value);
        if (found) return value;

        final native = _natives.get(expr.value);
        if (native != null) return NativeFunctionValue(native);

        throw Exception('undefined variable: ${expr.value}');
      case FunctionLiteral():
        return FunctionValue(expr.parameters, expr.body, _env);
      case BinaryExpr():
        return _evalBinaryExpr(expr);
      case UnaryExpr():
        return _evalUnaryExpr(expr);
      case SafeAccessExpr():
        return _evalSafeAccess(expr);
      case ElvisExpr():
        return _evalElvisExpr(expr);
      case PropertyAccessExpr():
        return _evalPropertyAccess(expr);
      case CallExpr():
        return _evalCallExpr(expr);
      case ArrayLiteral():
        return expr.elements.map((e) => _evalExpression(e)).toList();
      case ObjectLiteral():
        return expr.pairs.map((k, v) => MapEntry(k, _evalExpression(v)));
      case IndexExpr():
        return _evalIndexExpression(expr);
    }
  }

  Object? _evalAssignment(Expression left, Expression rightExpr) {
    final right = _evalExpression(rightExpr);

    switch (left) {
      case Identifier():
        _env.update(left.value, right);
        return right;

      case IndexExpr():
        final target = _evalExpression(left.left);
        final index = _evalExpression(left.index);

        if (target is List) {
          final idx = _toNumber(index).toInt();
          // Auto-expand list if assigning directly to length
          if (idx == target.length) {
            target.add(right);
            return right;
          }
          if (idx < 0 || idx > target.length) {
             throw RangeError('Index out of range: $idx (length: ${target.length})');
          }
          target[idx] = right;
          return right;
        } else if (target is Map) {
          target[index.toString()] = right;
          return right;
        }
        throw Exception("Cannot assign to index of ${target.runtimeType}");

      case PropertyAccessExpr():
        final target = _evalExpression(left.obj);
        final property = left.property.value;

        if (target is Map) {
          target[property] = right;
          return right;
        }
        throw Exception("Cannot assign property '$property' on ${target.runtimeType}");

      default:
        throw Exception("Invalid assignment target: ${left.runtimeType}");
    }
  }

  Object? _evalIndexExpression(IndexExpr expr) {
    final left = _evalExpression(expr.left);
    final index = _evalExpression(expr.index);

    if (left is List) {
      final idx = _toNumber(index).toInt();
      if (idx < 0 || idx >= left.length) return null;
      return left[idx];
    }

    if (left is Map) {
      final key = index.toString();
      return left[key];
    }

    throw Exception('index operator not supported: ${left?.runtimeType}');
  }

  Object? _evalBinaryExpr(BinaryExpr expr) {
    if (expr.operator == '=') {
      return _evalAssignment(expr.left, expr.right);
    }

    final left = _evalExpression(expr.left);

    // Short-circuit for && and ||
    switch (expr.operator) {
      case '&&':
        if (!_isTruthy(left)) return false;
        return _isTruthy(_evalExpression(expr.right));
      case '||':
        if (_isTruthy(left)) return true;
        return _isTruthy(_evalExpression(expr.right));
    }

    final right = _evalExpression(expr.right);

    switch (expr.operator) {
      case '+':
        return _evalPlus(left, right);
      case '-':
        return _toNumber(left) - _toNumber(right);
      case '*':
        return _toNumber(left) * _toNumber(right);
      case '/':
        final r = _toNumber(right);
        if (r == 0) throw Exception('division by zero');
        return _toNumber(left) / r;
      case '%':
        final r = _toNumber(right);
        if (r == 0) throw Exception('modulo by zero');
        return _toNumber(left) % r;
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '<':
        return _toNumber(left) < _toNumber(right);
      case '>':
        return _toNumber(left) > _toNumber(right);
      case '<=':
        return _toNumber(left) <= _toNumber(right);
      case '>=':
        return _toNumber(left) >= _toNumber(right);
      default:
        throw Exception('unknown operator: ${expr.operator}');
    }
  }

  Object? _evalPlus(Object? left, Object? right) {
    if (left is String || right is String) {
      return '${left ?? "null"}${right ?? "null"}';
    }
    return _toNumber(left) + _toNumber(right);
  }

  Object? _evalUnaryExpr(UnaryExpr expr) {
    final right = _evalExpression(expr.right);
    switch (expr.operator) {
      case '-':
        return -_toNumber(right);
      case '!':
        return !_isTruthy(right);
      default:
        throw Exception('unknown unary operator: ${expr.operator}');
    }
  }

  Object? _evalSafeAccess(SafeAccessExpr expr) {
    final obj = _evalExpression(expr.obj);
    if (obj == null) return null;

    if (obj is Map) {
      return obj[expr.property.value];
    }
    return null;
  }

  Object? _evalElvisExpr(ElvisExpr expr) {
    final left = _evalExpression(expr.left);
    return left ?? _evalExpression(expr.defaultValue);
  }

  Object? _evalPropertyAccess(PropertyAccessExpr expr) {
    final obj = _evalExpression(expr.obj);
    if (obj == null) {
      throw Exception("cannot access property '${expr.property.value}' on null");
    }

    final prop = expr.property.value;

    // First check for map access (existing behavior)
    if (obj is Map) {
      return obj[prop];
    }
    
    // Check for List access
    if (obj is List) {
      final listObj = obj;
      
      if (prop == 'size') {
        return NativeFunctionValue((args) => listObj.length.toDouble());
      }
      if (prop == 'length') {
        return listObj.length.toDouble();
      }
      if (prop == 'add') {
        return NativeFunctionValue((args) {
           listObj.add(args[0]);
           return null;
        });
      }
      if (prop == 'isEmpty') {
        return listObj.isEmpty;
      }
      if (prop == 'isNotEmpty') {
        return listObj.isNotEmpty;
      }
      if (prop == 'contains') {
        return NativeFunctionValue((args) {
           return listObj.contains(args[0]);
        });
      }
      if (prop == 'clear') {
         return NativeFunctionValue((args) {
            listObj.clear();
            return null;
         });
      }
      
      // -- Higher Order Methods --
      
      if (prop == 'map') {
        return NativeFunctionValue((args) {
          if (args.isEmpty) return [];
          final fn = args[0];
          return listObj.asMap().entries.map((e) => 
            _applyFunction(fn, [e.value, e.key.toDouble()])
          ).toList();
        });
      }

      if (prop == 'filter' || prop == 'where') {
        return NativeFunctionValue((args) {
          if (args.isEmpty) return [];
          final fn = args[0];
          final result = <Object?>[];
          for (var i = 0; i < listObj.length; i++) {
            if (_isTruthy(_applyFunction(fn, [listObj[i], i.toDouble()]))) {
              result.add(listObj[i]);
            }
          }
          return result;
        });
      }

      if (prop == 'forEach') {
        return NativeFunctionValue((args) {
          if (args.isEmpty) return null;
          final fn = args[0];
          for (var i = 0; i < listObj.length; i++) {
            _applyFunction(fn, [listObj[i], i.toDouble()]);
          }
          return null;
        });
      }

      if (prop == 'any') {
        return NativeFunctionValue((args) {
          if (args.isEmpty) return false;
          final fn = args[0];
          for (var i = 0; i < listObj.length; i++) {
            if (_isTruthy(_applyFunction(fn, [listObj[i], i.toDouble()]))) return true;
          }
          return false;
        });
      }

      if (prop == 'every') {
        return NativeFunctionValue((args) {
          if (args.isEmpty) return true;
          final fn = args[0];
          for (var i = 0; i < listObj.length; i++) {
            if (!_isTruthy(_applyFunction(fn, [listObj[i], i.toDouble()]))) return false;
          }
          return true;
        });
      }
    }

    // Use reflection to access methods and fields on Dart objects
    return _reflectivePropertyAccess(obj, prop);
  }

  Object? _evalCallExpr(CallExpr expr) {
    final funcExpr = expr.function;

    // Special print handling
    if (funcExpr is Identifier && funcExpr.value == 'print') {
      final args = expr.arguments.map((a) => _evalExpression(a)).toList();
      for (final arg in args) {
        final output = arg?.toString() ?? 'null';
        log(output, name: 'KodiScript');
        _env.addOutput(output);
      }
      return null;
    }

    // Special handling for higher-order array functions
    if (funcExpr is Identifier) {
      switch (funcExpr.value) {
        case 'map':
          return _evalMapFunction(expr);
        case 'filter':
          return _evalFilterFunction(expr);
        case 'reduce':
          return _evalReduceFunction(expr);
        case 'find':
          return _evalFindFunction(expr);
        case 'findIndex':
          return _evalFindIndexFunction(expr);
      }
    }

    final function = _evalExpression(funcExpr);
    final args = expr.arguments.map((a) => _evalExpression(a)).toList();

    return _applyFunction(function, args);
  }

  Object? _evalMapFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      throw Exception('map requires 2 arguments: array and function');
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return <Object?>[];
    final fnVal = _evalExpression(expr.arguments[1]);
    return arrVal.asMap().entries.map((e) => 
      _applyFunction(fnVal, [e.value, e.key.toDouble()])
    ).toList();
  }

  Object? _evalFilterFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      throw Exception('filter requires 2 arguments: array and function');
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return <Object?>[];
    final fnVal = _evalExpression(expr.arguments[1]);
    final result = <Object?>[];
    for (var i = 0; i < arrVal.length; i++) {
      if (_isTruthy(_applyFunction(fnVal, [arrVal[i], i.toDouble()]))) {
        result.add(arrVal[i]);
      }
    }
    return result;
  }

  Object? _evalReduceFunction(CallExpr expr) {
    if (expr.arguments.length < 3) {
      throw Exception('reduce requires 3 arguments: array, function, and initial value');
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return null;
    final fnVal = _evalExpression(expr.arguments[1]);
    var accumulator = _evalExpression(expr.arguments[2]);
    for (var i = 0; i < arrVal.length; i++) {
      accumulator = _applyFunction(fnVal, [accumulator, arrVal[i], i.toDouble()]);
    }
    return accumulator;
  }

  Object? _evalFindFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      throw Exception('find requires 2 arguments: array and function');
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return null;
    final fnVal = _evalExpression(expr.arguments[1]);
    for (var i = 0; i < arrVal.length; i++) {
      if (_isTruthy(_applyFunction(fnVal, [arrVal[i], i.toDouble()]))) {
        return arrVal[i];
      }
    }
    return null;
  }

  Object? _evalFindIndexFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      throw Exception('findIndex requires 2 arguments: array and function');
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return -1.0;
    final fnVal = _evalExpression(expr.arguments[1]);
    for (var i = 0; i < arrVal.length; i++) {
      if (_isTruthy(_applyFunction(fnVal, [arrVal[i], i.toDouble()]))) {
        return i.toDouble();
      }
    }
    return -1.0;
  }

  Object? _applyFunction(Object? fn, List<Object?> args) {
    if (fn is FunctionValue) {
      final extendedEnv = Environment(fn.env);
      for (var i = 0; i < fn.parameters.length; i++) {
        final val = (i < args.length) ? args[i] : null;
        extendedEnv.set(fn.parameters[i].value, val);
      }

      final previousEnv = _env;
      _env = extendedEnv;
      try {
        final result = _evalBlockStatement(fn.body);
        if (result is ReturnValue) return result.value;
        return result;
      } finally {
        _env = previousEnv;
      }
    }

    if (fn is NativeFunctionValue) {
      return fn.fn(args);
    }

    throw Exception('not a function: ${fn?.runtimeType}');
  }

  bool _isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    return true;
  }


  double _toNumber(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ============ Bindable Object Support ============

  /// Accesses properties on KodiBindable objects.
  Object? _reflectivePropertyAccess(Object obj, String propertyName) {
    if (obj is! KodiBindable) {
      throw Exception(
          "cannot access property '$propertyName' on ${obj.runtimeType}: "
          "object must implement KodiBindable");
    }

    // First try to get as a property
    final propValue = obj.getProperty(propertyName);
    if (propValue != null) {
      return _convertFromDartType(propValue);
    }

    // Otherwise return a callable wrapper for method invocation
    return NativeFunctionValue((args) {
      final result = obj.callMethod(propertyName, args);
      if (result is _MethodNotFound) {
        throw Exception(
            "method or property '$propertyName' not found on ${obj.runtimeType}");
      }
      return _convertFromDartType(result);
    });
  }

  /// Converts a Dart value to a KodiScript-compatible value.
  Object? _convertFromDartType(Object? value) {
    if (value == null) return null;

    // Convert Dart ints to doubles (KodiScript's number type)
    if (value is int) return value.toDouble();

    // Return other types as-is (String, double, bool, List, Map, custom objects)
    return value;
  }
}
