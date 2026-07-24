/// Classifies why execution failed, for programmatic handling.
///
/// Mirrors the Go/Kotlin/TS `ErrorKind` so hosts can branch on the cause of a
/// failure across every KodiScript implementation.
enum ErrorKind {
  /// No error (successful execution).
  none,

  /// The script failed to parse.
  parse,

  /// A runtime error occurred during evaluation.
  runtime,

  /// Execution exceeded the configured timeout.
  timeout,

  /// Execution exceeded the configured operation limit.
  maxOperations,
}

/// Result of a KSEngine operation.
///
/// Contains the execution result, any errors that occurred,
/// and the success status of the operation.
class KSEngineResult {
  /// The return value of the operation (if successful).
  final Object? value;

  /// List of error messages (if any).
  final List<String> errors;

  /// Whether the operation was successful.
  final bool success;

  /// Output lines produced during execution (e.g., from print statements).
  final List<String> output;

  /// Classifies the failure ([ErrorKind.none] on success).
  final ErrorKind errorKind;

  const KSEngineResult._({
    this.value,
    this.errors = const [],
    this.output = const [],
    required this.success,
    this.errorKind = ErrorKind.none,
  });

  /// Creates a successful result.
  factory KSEngineResult.success({Object? value, List<String> output = const []}) =>
      KSEngineResult._(value: value, output: output, success: true);

  /// Creates an error result.
  factory KSEngineResult.error(List<String> errors,
          {ErrorKind errorKind = ErrorKind.runtime}) =>
      KSEngineResult._(errors: errors, success: false, errorKind: errorKind);

  /// Whether there are any errors.
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    if (success) {
      return 'KSEngineResult.success(value: $value)';
    }
    return 'KSEngineResult.error(errors: $errors)';
  }
}
