/// KodiScript Interpreter - Evaluates AST nodes.
library;

import 'dart:developer';

import '../ast/ast.dart';
import '../natives/natives.dart';

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

  void addOutput(String line) {
    _output.add(line);
  }

  List<String> getOutput() => List.unmodifiable(_output);
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

/// Interpreter evaluates AST nodes.
class Interpreter {
  Environment _env;
  final NativeFunctions _natives;

  Interpreter({Environment? env, NativeFunctions? natives})
      : _env = env ?? Environment(),
        _natives = natives ?? NativeFunctions.shared;

  factory Interpreter.withVariables(Map<String, Object?> variables) {
    final env = Environment();
    variables.forEach((k, v) => env.set(k, v));
    return Interpreter(env: env);
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

  List<String> getOutput() => _env.getOutput();

  Object? _evalStatement(Statement stmt) {
    switch (stmt) {
      case VarDecl():
        final value = _evalExpression(stmt.value);
        _env.set(stmt.name.value, value);
        return value;
      case Assignment():
        final value = _evalExpression(stmt.value);
        _env.set(stmt.name.value, value);
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
      _env.set(varName, item);
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

    if (obj is Map) {
      return obj[expr.property.value];
    }
    throw Exception('cannot access property on ${obj.runtimeType}');
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
      for (var i = 0; i < fn.parameters.length && i < args.length; i++) {
        extendedEnv.set(fn.parameters[i].value, args[i]);
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
}
