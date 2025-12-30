# KodiScript Dart SDK

A lightweight, embeddable scripting language for Dart applications.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kodi_script: ^1.0.0
```

## Quick Start

```dart
import 'package:kodi_script/kodi_script.dart';

void main() {
  // Simple evaluation
  final result = KodiScript.eval('2 + 3 * 4');
  print(result); // 14.0

  // With variables
  final greeting = KodiScript.run(
    'greeting + ", " + name + "!"',
    variables: {'greeting': 'Hello', 'name': 'World'},
  );
  print(greeting.value); // "Hello, World!"

  // Capture output
  final output = KodiScript.run('''
    let items = ["apple", "banana", "cherry"]
    for (item in items) {
      print(item)
    }
  ''');
  print(output.output); // ["apple", "banana", "cherry"]
}
```

## Features

- **Variables**: `let x = 10`
- **Functions**: `fn(a, b) { return a + b }`
- **Control Flow**: `if`, `else`, `for-in`
- **Data Types**: numbers, strings, booleans, arrays, objects
- **Null Safety**: `?.` (safe access), `?:` (elvis operator)
- **48+ Native Functions**: string, math, random, type, array, JSON, encoding, crypto

## Custom Functions

```dart
final result = KodiScript.builder('greet("Dart")')
    .registerFunction('greet', (args) => 'Hello, ${args[0]}!')
    .execute();

print(result.value); // "Hello, Dart!"
```

## API Reference

### KodiScript.eval(source)
Evaluates a script and returns the result value.

### KodiScript.run(source, {variables})
Runs a script with optional variables and returns `ScriptResult`.

### KodiScript.builder(source)
Creates a builder for advanced configuration.

## Native Functions

| Category | Functions |
|----------|-----------|
| String | `toString`, `toNumber`, `length`, `substring`, `toUpperCase`, `toLowerCase`, `trim`, `split`, `join`, `replace`, `contains`, `startsWith`, `endsWith`, `indexOf` |
| Math | `abs`, `floor`, `ceil`, `round`, `min`, `max`, `pow`, `sqrt`, `sin`, `cos`, `tan`, `log`, `log10`, `exp` |
| Random | `random`, `randomInt`, `randomUUID` |
| Type | `typeOf`, `isNull`, `isNumber`, `isString`, `isBool` |
| Array | `size`, `first`, `last`, `reverse`, `slice`, `sort` |
| JSON | `jsonParse`, `jsonStringify` |
| Encoding | `base64Encode`, `base64Decode`, `urlEncode`, `urlDecode` |
| Crypto | `md5`, `sha1`, `sha256` |

## License

MIT
