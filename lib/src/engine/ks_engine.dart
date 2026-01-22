/// KSEngine - Persistent script engine for mini-app execution.
///
/// This engine maintains script context between invocations,
/// allowing state persistence and reactive updates.
library;

import '../lexer/lexer.dart';
import '../parser/parser.dart';
import '../ast/ast.dart';
import '../interpreter/interpreter.dart';
import '../natives/natives.dart';
import '../reactive/rx.dart';
import 'ks_engine_result.dart';

export 'ks_engine_result.dart';

/// Persistent script engine for mini-app execution.
///
/// Usage:
/// ```dart
/// final engine = KSEngine();
///
/// // Load and initialize the script
/// await engine.load('''
///   var counter = Obs(0)
///
///   function increment() {
///     counter.set(counter.value + 1)
///   }
///
///   function build() {
///     return { "type": "Text", "props": { "content": counter.value } }
///   }
/// ''');
///
/// // Get initial UI
/// final ui = await engine.invoke('build');
///
/// // Handle user action
/// await engine.invoke('increment');
///
/// // Get updated UI
/// final updatedUi = await engine.invoke('build');
/// ```
class KSEngine {
  /// The parsed program AST.
  Program? _program;

  /// The persistent environment holding variables and functions.
  Environment? _env;

  /// The interpreter for evaluating expressions.
  Interpreter? _interpreter;

  /// Native functions available to the script.
  NativeFunctions? _natives;

  /// Whether the engine has been loaded.
  bool _loaded = false;

  /// Creates a new KSEngine instance.
  KSEngine() {
    _initNatives();
  }

  /// Whether the engine is loaded and ready for invocation.
  bool get isLoaded => _loaded;

  /// Initializes native functions including reactive primitives.
  void _initNatives() {
    _natives = NativeFunctions.withBuiltins();
    // Register Obs function for creating reactive variables
    _natives!.register('Obs', createObs);
  }

  /// Loads and initializes a script.
  ///
  /// This parses the source code and executes the global scope
  /// to initialize variables and function definitions.
  ///
  /// Call this once before using [invoke].
  Future<KSEngineResult> load(String source) async {
    // Reset state
    _loaded = false;
    _program = null;

    // Parse the source
    final lexer = Lexer(source);
    final parser = Parser(lexer);
    _program = parser.parseProgram();

    // Check for parse errors
    if (parser.errors().isNotEmpty) {
      return KSEngineResult.error(parser.errors());
    }

    // Create fresh environment and interpreter
    _env = Environment();
    _interpreter = Interpreter(env: _env!, natives: _natives!);

    // Execute global scope to initialize state
    try {
      _interpreter!.eval(_program!);
      _loaded = true;
      return KSEngineResult.success(output: _interpreter!.getOutput());
    } catch (e) {
      return KSEngineResult.error([e.toString()]);
    }
  }

  /// Invokes a function defined in the loaded script.
  ///
  /// The function is executed with the current context,
  /// preserving all state from previous invocations.
  ///
  /// [funcName] - The name of the function to call.
  /// [args] - Optional arguments to pass to the function.
  ///
  /// Returns a [KSEngineResult] with the function's return value.
  Future<KSEngineResult> invoke(String funcName, [List<Object?> args = const []]) async {
    if (!_loaded) {
      return KSEngineResult.error(['Engine not loaded. Call load() first.']);
    }

    // Look up the function in the environment
    final (funcValue, found) = _env!.get(funcName);

    if (!found) {
      return KSEngineResult.error(['Function "$funcName" not found']);
    }

    if (funcValue is! FunctionValue) {
      return KSEngineResult.error(['"$funcName" is not a function']);
    }

    try {
      final result = _interpreter!.callFunction(funcValue, args);
      return KSEngineResult.success(
        value: result,
        output: _interpreter!.getOutput(),
      );
    } catch (e) {
      return KSEngineResult.error([e.toString()]);
    }
  }

  /// Invokes a function synchronously.
  ///
  /// Throws if the engine is not loaded or the function doesn't exist.
  Object? invokeSync(String funcName, [List<Object?> args = const []]) {
    if (!_loaded) {
      throw StateError('Engine not loaded. Call load() first.');
    }

    final (funcValue, found) = _env!.get(funcName);

    if (!found) {
      throw ArgumentError('Function "$funcName" not found');
    }

    if (funcValue is! FunctionValue) {
      throw ArgumentError('"$funcName" is not a function');
    }

    return _interpreter!.callFunction(funcValue, args);
  }

  /// Gets a variable from the script context.
  ///
  /// Returns null if the variable doesn't exist or engine isn't loaded.
  Object? getVariable(String name) {
    if (_env == null) return null;
    final (value, found) = _env!.get(name);
    return found ? value : null;
  }

  /// Sets a variable in the script context.
  ///
  /// This can be used to inject values from the host application.
  void setVariable(String name, Object? value) {
    _env?.set(name, value);
  }

  /// Binds a Dart object to the script context.
  ///
  /// The object must implement [KodiBindable].
  void bind(String name, KodiBindable value) {
    _env?.set(name, value);
  }

  /// Returns a snapshot of the current state.
  ///
  /// Useful for debugging or serialization.
  Map<String, Object?> getState() {
    return _env?.toMap() ?? {};
  }

  /// Returns all output produced during script execution.
  List<String> getOutput() {
    return _interpreter?.getOutput() ?? [];
  }

  /// Clears the output buffer.
  void clearOutput() {
    _interpreter?.clearOutput();
  }

  /// Resets the engine to its initial state.
  ///
  /// After calling this, you must call [load] again.
  void reset() {
    _program = null;
    _env = null;
    _interpreter = null;
    _loaded = false;
    _initNatives();
  }

  /// Disposes all resources held by the engine.
  void dispose() {
    _program = null;
    _env = null;
    _interpreter = null;
    _natives = null;
    _loaded = false;
  }
}
