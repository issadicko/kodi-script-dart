/// Example demonstrating the KodiScript SDK.
///
/// Run with: dart run example/kodi_script_example.dart

import 'package:kodi_script/kodi_script.dart';

// Example bindable class
class Calculator implements KodiBindable {
  double add(double a, double b) => a + b;
  double multiply(double a, double b) => a * b;

  @override
  Object? getProperty(String name) => null;

  @override
  Object? callMethod(String name, List<Object?> args) {
    final a = (args[0] as num).toDouble();
    final b = (args[1] as num).toDouble();
    switch (name) {
      case 'add':
        return add(a, b);
      case 'multiply':
        return multiply(a, b);
      default:
        return null;
    }
  }
}

void main() {
  // Basic variable usage
  print('=== Basic Variables ===');
  final result1 = KodiScript.run('''
    let name = "KodiScript"
    let version = 0.2
    print("Welcome to " + name + " v" + version)
    name + " is awesome!"
  ''');
  print('Output: ${result1.output}');
  print('Result: ${result1.value}\n');

  // Control flow with if/else
  print('=== Control Flow ===');
  final result2 = KodiScript.run('''
    let score = 85
    if (score >= 90) {
      "A"
    } else if (score >= 80) {
      "B"
    } else {
      "C"
    }
  ''');
  print('Grade: ${result2.value}\n');

  // For loop iteration
  print('=== For Loop ===');
  final result3 = KodiScript.run('''
    let numbers = [1, 2, 3, 4, 5]
    let sum = 0
    for (n in numbers) {
      sum = sum + n
    }
    sum
  ''');
  print('Sum of 1-5: ${result3.value}\n');

  // While loop
  print('=== While Loop ===');
  final result4 = KodiScript.run('''
    let i = 1
    let product = 1
    while (i <= 5) {
      product = product * i
      i = i + 1
    }
    product
  ''');
  print('5! = ${result4.value}\n');

  // User-defined functions
  print('=== Functions ===');
  final result5 = KodiScript.run('''
    let greet = fn(name) {
      return "Hello, " + name + "!"
    }
    
    let square = fn(x) {
      return x * x
    }
    
    greet("World") + " 5² = " + square(5)
  ''');
  print('Result: ${result5.value}\n');

  // Binding Dart objects
  print('=== Object Binding ===');
  final calc = Calculator();
  final result6 = KodiScript.builder('''
    let a = 10
    let b = 5
    print("Add: " + calc.add(a, b))
    print("Multiply: " + calc.multiply(a, b))
    calc.add(a, b) + calc.multiply(a, b)
  ''').bind('calc', calc).execute();
  print('Output: ${result6.output}');
  print('Result: ${result6.value}\n');

  // Array higher-order functions
  print('=== Higher-Order Functions ===');
  final result7 = KodiScript.run('''
    let numbers = [1, 2, 3, 4, 5]
    
    // Double each number
    let doubled = map(numbers, fn(x) { return x * 2 })
    
    // Filter even numbers from doubled
    let evens = filter(doubled, fn(x) { return x % 4 == 0 })
    
    // Sum them up
    reduce(evens, fn(acc, x) { return acc + x }, 0)
  ''');
  print('Sum of (doubled numbers divisible by 4): ${result7.value}\n');

  // Null-safe operations
  print('=== Null Safety ===');
  final result8 = KodiScript.run('''
    let user = { "name": "Alice", "email": null }
    let email = user?.email ?: "no-email@example.com"
    email
  ''');
  print('Email: ${result8.value}');
}
