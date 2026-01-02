/// KodiScript - A lightweight, embeddable scripting language for Dart.
///
/// Usage:
/// ```dart
/// import 'package:kodi_script/kodi_script.dart';
///
/// final result = KodiScript.run('''
///   let name = "Kodi"
///   print("Hello " + name)
/// ''');
///
/// print(result.output); // ["Hello Kodi"]
/// ```
library kodi_script;

export 'src/token/token.dart';
export 'src/lexer/lexer.dart';
export 'src/ast/ast.dart';
export 'src/parser/parser.dart';
export 'src/interpreter/interpreter.dart';
export 'src/natives/natives.dart';

import 'src/lexer/lexer.dart';
import 'src/parser/parser.dart';
import 'src/interpreter/interpreter.dart';
import 'src/natives/natives.dart';
import 'src/cache/ast_cache.dart';

/// Result of script execution.
class ScriptResult {
  final Object? value;
  final List<String> output;
  final List<String> errors;

  const ScriptResult({
    this.value,
    this.output = const [],
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// KodiScript is the main entry point for the KodiScript SDK.
class KodiScript {
  final String _source;
  final Map<String, Object?> _variables;
  final Map<String, NativeFunc> _customFunctions;
  final bool _useCache;
  final int _maxOps;
  final Duration _timeout;

  KodiScript._({
    required String source,
    Map<String, Object?>? variables,
    Map<String, NativeFunc>? customFunctions,
    bool useCache = true,
    int maxOps = 0,
    Duration timeout = Duration.zero,
  })  : _source = source,
        _variables = variables ?? {},
        _customFunctions = customFunctions ?? {},
        _useCache = useCache,
        _maxOps = maxOps,
        _timeout = timeout;

  /// Builder for KodiScript execution.
  static KodiScriptBuilder builder(String source) => KodiScriptBuilder(source);

  /// Run a script with optional variables.
  static ScriptResult run(String source, {Map<String, Object?>? variables}) {
    return KodiScriptBuilder(source)
        .withVariables(variables ?? {})
        .execute();
  }

  /// Simple evaluation function.
  static Object? eval(String source) {
    final result = run(source);
    if (result.hasErrors) {
      throw KodiScriptException(result.errors);
    }
    return result.value;
  }

  ScriptResult _execute() {
    // Try cache first
    var program = _useCache ? ASTCache.defaultCache.get(_source) : null;

    if (program == null) {
      // Lexer
      final lexer = Lexer(_source);

      // Parser
      final parser = Parser(lexer);
      program = parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        return ScriptResult(errors: parser.errors());
      }

      // Store in cache
      if (_useCache) {
        ASTCache.defaultCache.set(_source, program);
      }
    }

    // Use singleton for built-ins, create copy only if custom functions registered
    NativeFunctions natives;
    if (_customFunctions.isEmpty) {
      natives = NativeFunctions.shared;
    } else {
      natives = NativeFunctions.withBuiltins();
      _customFunctions.forEach((name, fn) => natives.register(name, fn));
    }

    // Interpreter with environment and natives
    final env = Environment();
    _variables.forEach((k, v) => env.set(k, v));
    final interpreter = Interpreter(env: env, natives: natives);

    // Apply operation limit if set
    if (_maxOps > 0) {
      interpreter.setMaxOperations(_maxOps);
    }

    // Apply timeout if set
    if (_timeout > Duration.zero) {
      interpreter.setDeadline(
          DateTime.now().millisecondsSinceEpoch + _timeout.inMilliseconds);
    }

    try {
      final value = interpreter.eval(program);
      return ScriptResult(value: value, output: interpreter.getOutput());
    } catch (e) {
      return ScriptResult(errors: [e.toString()]);
    }
  }
}

/// Builder for KodiScript execution.
class KodiScriptBuilder {
  final String _source;
  final Map<String, Object?> _variables = {};
  final Map<String, NativeFunc> _customFunctions = {};
  bool _useCache = true;
  int _maxOps = 0; // 0 = unlimited
  Duration _timeout = Duration.zero; // zero = no timeout

  KodiScriptBuilder(this._source);

  /// Inject host variables into the script context.
  KodiScriptBuilder withVariables(Map<String, Object?> vars) {
    _variables.addAll(vars);
    return this;
  }

  /// Inject a single variable.
  KodiScriptBuilder withVariable(String name, Object? value) {
    _variables[name] = value;
    return this;
  }

  /// Register a custom native function.
  KodiScriptBuilder registerFunction(String name, NativeFunc fn) {
    _customFunctions[name] = fn;
    return this;
  }

  /// Bind a Dart object to the script context with reflective access.
  /// All public methods and fields of the object will be accessible from KodiScript.
  KodiScriptBuilder bind(String name, Object obj) {
    _variables[name] = obj;
    return this;
  }

  /// Enable or disable AST caching.
  KodiScriptBuilder withCache(bool enabled) {
    _useCache = enabled;
    return this;
  }

  /// Set the maximum number of operations allowed.
  /// Use this to protect against infinite loops.
  KodiScriptBuilder withMaxOperations(int maxOps) {
    _maxOps = maxOps;
    return this;
  }

  /// Set the execution timeout.
  KodiScriptBuilder withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// Execute the script.
  ScriptResult execute() {
    return KodiScript._(
      source: _source,
      variables: _variables,
      customFunctions: _customFunctions,
      useCache: _useCache,
      maxOps: _maxOps,
      timeout: _timeout,
    )._execute();
  }
}

/// Exception thrown when script execution fails.
class KodiScriptException implements Exception {
  final List<String> errors;

  KodiScriptException(this.errors);

  @override
  String toString() => errors.isNotEmpty ? errors.first : 'Unknown error';
}
