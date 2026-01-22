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

  const KSEngineResult._({
    this.value,
    this.errors = const [],
    this.output = const [],
    required this.success,
  });

  /// Creates a successful result.
  factory KSEngineResult.success({Object? value, List<String> output = const []}) =>
      KSEngineResult._(value: value, output: output, success: true);

  /// Creates an error result.
  factory KSEngineResult.error(List<String> errors) =>
      KSEngineResult._(errors: errors, success: false);

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
