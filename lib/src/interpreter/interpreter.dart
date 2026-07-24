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

/// Interface for objects that support custom assignment logic.
///
/// If a variable holding a KodiAssignable object is assigned a new value,
/// the interpreter calls [assign] instead of overwriting the variable.
abstract class KodiAssignable {
  void assign(Object? value);
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
      final existing = _store[name];
      // Smart assignment: if the object is Assignable, let it handle the value
      if (existing is KodiAssignable) {
        existing.assign(value);
      } else {
        _store[name] = value;
      }
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

/// Signals a `break` out of the nearest enclosing loop.
class BreakValue {
  const BreakValue();
}

/// Signals a `continue` to the next iteration of the nearest loop.
class ContinueValue {
  const ContinueValue();
}

const _breakSignal = BreakValue();
const _continueSignal = ContinueValue();

/// Bounds nested user-function calls, guarding against unbounded recursion
/// exhausting the native stack.
const int _maxCallDepth = 1000;

/// Exception thrown when the function call depth limit is exceeded.
class StackOverflowExceeded implements Exception {
  @override
  String toString() => 'maximum call depth exceeded';
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
  int _callDepth = 0; // current user-function call depth (recursion guard)
  void Function(String)? _outputSink; // routes print() output when set

  Interpreter({Environment? env, NativeFunctions? natives})
      : _env = env ?? Environment(),
        _natives = natives ?? NativeFunctions.shared;

  /// Routes print() output to the given callback instead of the default logger.
  /// Output is still captured and available via [getOutput].
  void setOutputSink(void Function(String) sink) {
    _outputSink = sink;
  }

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
      final val = _evalStatement(stmt);
      if (val is ReturnValue) {
        return val.value;
      }
      // Ignore a stray break/continue used outside any loop.
      if (val is BreakValue || val is ContinueValue) {
        continue;
      }
      result = val;
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
      case ArrayDestructure():
        return _evalArrayDestructure(stmt);
      case ObjectDestructure():
        return _evalObjectDestructure(stmt);
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
      case TryStatement():
        return _evalTryStatement(stmt);
      case BreakStatement():
        return _breakSignal;
      case ContinueStatement():
        return _continueSignal;
      case FunctionDeclaration():
        final fn = FunctionValue(stmt.parameters, stmt.body, _env);
        _env.set(stmt.name.value, fn);
        return null; // Function declaration statement returns null
    }
  }

  Object? _evalArrayDestructure(ArrayDestructure stmt) {
    final value = _evalExpression(stmt.value);
    if (value is! List) {
      throw Exception('cannot destructure non-array value (${value?.runtimeType})');
    }
    for (var idx = 0; idx < stmt.names.length; idx++) {
      _env.set(stmt.names[idx].value, idx < value.length ? value[idx] : null);
    }
    return value;
  }

  Object? _evalObjectDestructure(ObjectDestructure stmt) {
    final value = _evalExpression(stmt.value);
    if (value is! Map) {
      throw Exception('cannot destructure non-object value (${value?.runtimeType})');
    }
    for (final name in stmt.names) {
      _env.set(name.value, value[name.value]);
    }
    return value;
  }

  /// Runs the protected block; on a (non-limit) runtime error it binds the
  /// error message to the catch variable and runs the handler.
  Object? _evalTryStatement(TryStatement stmt) {
    try {
      return _evalBlockStatement(stmt.body);
    } catch (e) {
      // Timeout / operation-limit errors are not catchable (mirrors Go).
      if (e is TimeoutException || e is MaxOperationsExceeded) {
        rethrow;
      }
      if (stmt.catchVar != null) {
        _env.set(stmt.catchVar!.value, _errorMessage(e));
      }
      return _evalBlockStatement(stmt.catchBlock);
    }
  }

  /// Produces a clean error message for a catch binding, stripping Dart's
  /// "Exception: " / "ArgumentError: " prefixes for cross-engine parity.
  static String _errorMessage(Object e) {
    var msg = e.toString();
    for (final prefix in const [
      'Exception: ',
      'ArgumentError: ',
      'Invalid argument(s): ',
      'FormatException: ',
    ]) {
      if (msg.startsWith(prefix)) {
        return msg.substring(prefix.length);
      }
    }
    return msg;
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
      if (value is BreakValue) {
        return result;
      }
      if (value is ContinueValue) {
        continue;
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
      if (value is BreakValue) {
        return result;
      }
      if (value is ContinueValue) {
        continue;
      }
      result = value;
    }

    return result;
  }

  Object? _evalBlockStatement(BlockStatement block) {
    Object? result;
    for (final stmt in block.statements) {
      result = _evalStatement(stmt);
      // Propagate return/break/continue signals up to the nearest handler.
      if (result is ReturnValue || result is BreakValue || result is ContinueValue) {
        return result;
      }
    }
    return result;
  }

  String _evalStringTemplate(StringTemplate tmpl) {
    final buffer = StringBuffer();
    for (final part in tmpl.parts) {
      buffer.write(kodiStringify(_evalExpression(part)));
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
      case TernaryExpr():
        return _isTruthy(_evalExpression(expr.condition))
            ? _evalExpression(expr.consequent)
            : _evalExpression(expr.alternative);
      case SpreadExpr():
        // A bare spread outside an array/argument list is not meaningful.
        throw Exception('spread operator is only valid in arrays or call arguments');
      case PropertyAccessExpr():
        return _evalPropertyAccess(expr);
      case CallExpr():
        return _evalCallExpr(expr);
      case ArrayLiteral():
        return _evalElements(expr.elements);
      case ObjectLiteral():
        return expr.pairs.map((k, v) => MapEntry(k, _evalExpression(v)));
      case IndexExpr():
        return _evalIndexExpression(expr);
    }
  }

  /// Evaluates a list of expressions, expanding any `...spread` elements.
  List<Object?> _evalElements(List<Expression> exprs) {
    final result = <Object?>[];
    for (final el in exprs) {
      if (el is SpreadExpr) {
        final v = _evalExpression(el.value);
        if (v is List) {
          result.addAll(v);
        } else {
          throw Exception('spread operator requires an array, got ${v?.runtimeType}');
        }
      } else {
        result.add(_evalExpression(el));
      }
    }
    return result;
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
    // String concatenation: the non-string operand is canonically stringified.
    if (left is String) return left + kodiStringify(right);
    if (right is String) return kodiStringify(left) + right;
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
    return _resolveMember(obj, expr.property.value);
  }

  /// Resolves a member (`prop`) on an already-evaluated receiver. Shared by
  /// plain property access and by method-call dispatch (step 4).
  Object? _resolveMember(Object? obj, String prop) {
    if (obj == null) {
      throw Exception("cannot access property '$prop' on null");
    }

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

  /// Interpreter builtins that need the interpreter itself (to capture output
  /// or to call back into user functions). Mirrors Go's interpBuiltins.
  static const Set<String> _interpBuiltins = {
    'print',
    'map',
    'filter',
    'reduce',
    'find',
    'findIndex',
    'some',
    'every',
    'flatMap',
  };

  Object? _evalCallExpr(CallExpr expr) {
    final funcExpr = expr.function;

    // Method-call syntax: receiver.method(args)
    if (funcExpr is PropertyAccessExpr) {
      return _evalMethodCall(funcExpr, expr.arguments);
    }

    // Interpreter builtins (print, map, filter, ...), unless overridden by a
    // user binding or a registered native of the same name.
    if (funcExpr is Identifier && _interpBuiltins.contains(funcExpr.value)) {
      final (_, inEnv) = _env.get(funcExpr.value);
      if (!inEnv && _natives.get(funcExpr.value) == null) {
        return _callBuiltin(funcExpr.value, _evalArgs(expr.arguments));
      }
    }

    // Default: evaluate the callee then apply it (user functions and natives).
    final function = _evalExpression(funcExpr);
    final args = _evalArgs(expr.arguments);
    return _applyFunction(function, args);
  }

  /// Implements method-call syntax: receiver.method(args). Mirrors Go's
  /// evalMethodCall dispatch order.
  Object? _evalMethodCall(PropertyAccessExpr pa, List<Expression> argExprs) {
    final receiver = _evalExpression(pa.obj);
    final method = pa.property.value;
    final args = _evalArgs(argExprs);

    // 1. A callable stored under that key on an object wins (obj.fn()).
    if (receiver is Map) {
      final v = receiver[method];
      if (_isCallable(v)) {
        return _applyFunction(v, args);
      }
    }

    // 2. Interpreter builtin invoked as a method: prepend the receiver.
    if (_interpBuiltins.contains(method)) {
      return _callBuiltin(method, [receiver, ...args]);
    }

    // 3. Registry native invoked as a method: prepend the receiver.
    final nfn = _natives.get(method);
    if (nfn != null) {
      return nfn([receiver, ...args]);
    }

    // 4. Bound object / List helpers via reflection.
    if (receiver == null) {
      throw Exception("cannot call method '$method' on null");
    }
    if (receiver is! Map) {
      final member = _resolveMember(receiver, method);
      return _applyFunction(member, args);
    }

    throw Exception("undefined method '$method'");
  }

  /// Evaluates a list of argument expressions, expanding any ...spread.
  List<Object?> _evalArgs(List<Expression> argExprs) => _evalElements(argExprs);

  static bool _isCallable(Object? v) =>
      v is FunctionValue || v is NativeFunctionValue;

  Object? _callBuiltin(String name, List<Object?> args) {
    switch (name) {
      case 'print':
        return _builtinPrint(args);
      case 'map':
        return _builtinMap(args);
      case 'filter':
        return _builtinFilter(args);
      case 'reduce':
        return _builtinReduce(args);
      case 'find':
        return _builtinFind(args);
      case 'findIndex':
        return _builtinFindIndex(args);
      case 'some':
        return _builtinSome(args);
      case 'every':
        return _builtinEvery(args);
      case 'flatMap':
        return _builtinFlatMap(args);
      default:
        throw Exception('unknown builtin: $name');
    }
  }

  Object? _builtinPrint(List<Object?> args) {
    for (final arg in args) {
      final output = kodiStringify(arg);
      if (_outputSink != null) {
        _outputSink!(output);
      } else {
        log(output, name: 'KodiScript');
      }
      _env.addOutput(output);
    }
    return null;
  }

  Object? _builtinMap(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('map requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return <Object?>[];
    final fn = args[1];
    return [
      for (var i = 0; i < arr.length; i++)
        _applyFunction(fn, [arr[i], i.toDouble()])
    ];
  }

  Object? _builtinFilter(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('filter requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return <Object?>[];
    final fn = args[1];
    final result = <Object?>[];
    for (var i = 0; i < arr.length; i++) {
      if (_isTruthy(_applyFunction(fn, [arr[i], i.toDouble()]))) {
        result.add(arr[i]);
      }
    }
    return result;
  }

  Object? _builtinReduce(List<Object?> args) {
    if (args.length < 3) {
      throw Exception('reduce requires 3 arguments: array, function, and initial value');
    }
    final arr = args[0];
    if (arr is! List) return null;
    final fn = args[1];
    var accumulator = args[2];
    for (var i = 0; i < arr.length; i++) {
      accumulator = _applyFunction(fn, [accumulator, arr[i], i.toDouble()]);
    }
    return accumulator;
  }

  Object? _builtinFind(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('find requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return null;
    final fn = args[1];
    for (var i = 0; i < arr.length; i++) {
      if (_isTruthy(_applyFunction(fn, [arr[i], i.toDouble()]))) {
        return arr[i];
      }
    }
    return null;
  }

  Object? _builtinFindIndex(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('findIndex requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return -1.0;
    final fn = args[1];
    for (var i = 0; i < arr.length; i++) {
      if (_isTruthy(_applyFunction(fn, [arr[i], i.toDouble()]))) {
        return i.toDouble();
      }
    }
    return -1.0;
  }

  Object? _builtinSome(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('some requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return false;
    final fn = args[1];
    for (var i = 0; i < arr.length; i++) {
      if (_isTruthy(_applyFunction(fn, [arr[i], i.toDouble()]))) return true;
    }
    return false;
  }

  Object? _builtinEvery(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('every requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return true;
    final fn = args[1];
    for (var i = 0; i < arr.length; i++) {
      if (!_isTruthy(_applyFunction(fn, [arr[i], i.toDouble()]))) return false;
    }
    return true;
  }

  Object? _builtinFlatMap(List<Object?> args) {
    if (args.length < 2) {
      throw Exception('flatMap requires 2 arguments: array and function');
    }
    final arr = args[0];
    if (arr is! List) return <Object?>[];
    final fn = args[1];
    final result = <Object?>[];
    for (var i = 0; i < arr.length; i++) {
      final val = _applyFunction(fn, [arr[i], i.toDouble()]);
      if (val is List) {
        result.addAll(val);
      } else {
        result.add(val);
      }
    }
    return result;
  }

  Object? _applyFunction(Object? fn, List<Object?> args) {
    if (fn is FunctionValue) {
      if (_callDepth >= _maxCallDepth) {
        throw StackOverflowExceeded();
      }
      _callDepth++;
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
        // A stray break/continue must not escape the function as a value.
        if (result is BreakValue || result is ContinueValue) return null;
        return result;
      } finally {
        _env = previousEnv;
        _callDepth--;
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
