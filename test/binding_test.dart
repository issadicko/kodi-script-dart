import 'package:kodi_script/kodi_script.dart';
import 'package:test/test.dart';

// Test classes for reflective binding
class Address {
  final String city;
  final String country;

  Address(this.city, this.country);
}

class User {
  final String name;
  final int age;
  final Address address;

  User(this.name, this.age, this.address);

  String sayHello() => "Hello, I'm $name";

  int getAge() => age;

  String greet(String greeting) => "$greeting, $name!";

  Address getAddress() => address;
}

class Calculator {
  double add(double a, double b) => a + b;

  int multiply(int x, int y) => x * y;

  double divide(double a, double b) {
    if (b == 0) return 0;
    return a / b;
  }
}

void main() {
  group('Reflective Binding Tests', () {
    test('bind field access', () {
      final user = User('Alice', 30, Address('Paris', 'France'));

      final result = KodiScript.builder('user.name').bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, 'Alice');
    });

    test('bind method call', () {
      final user = User('Bob', 25, Address('London', 'UK'));

      final result = KodiScript.builder('user.sayHello()').bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, "Hello, I'm Bob");
    });

    test('bind method with arguments', () {
      final user = User('Charlie', 28, Address('Berlin', 'Germany'));

      final result = KodiScript.builder('user.greet("Hi")').bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, "Hi, Charlie!");
    });

    test('bind nested objects', () {
      final user = User('David', 35, Address('Tokyo', 'Japan'));

      final result = KodiScript.builder('user.address.city').bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, 'Tokyo');
    });

    test('bind method chaining', () {
      final user = User('Emily', 32, Address('Madrid', 'Spain'));

      final result = KodiScript.builder('user.getAddress().city').bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, 'Madrid');
    });

    test('bind numeric conversion', () {
      final calc = Calculator();

      final result = KodiScript.builder('calc.add(10, 20)').bind('calc', calc).execute();

      expect(result.hasErrors, false);
      expect(result.value, 30.0);
    });

    test('bind int return converts to double', () {
      final user = User('Frank', 42, Address('Rome', 'Italy'));

      final result = KodiScript.builder('user.getAge()').bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, 42.0); // KodiScript uses doubles for numbers
    });

    test('bind multiple objects', () {
      final user = User('Grace', 27, Address('Amsterdam', 'Netherlands'));
      final calc = Calculator();

      const source = '''
        let greeting = user.sayHello()
        let sum = calc.add(5, 3)
        greeting + " " + sum
      ''';

      final result = KodiScript.builder(source)
          .bind('user', user)
          .bind('calc', calc)
          .execute();

      expect(result.hasErrors, false);
      expect(result.value, "Hello, I'm Grace 8.0");
    });

    test('bind complex script', () {
      final user = User('Henry', 29, Address('Vienna', 'Austria'));

      const source = '''
        let greeting = user.sayHello()
        let age = user.getAge()
        let city = user.address.city
        
        greeting + " I am " + age + " years old and I live in " + city
      ''';

      final result = KodiScript.builder(source).bind('user', user).execute();

      expect(result.hasErrors, false);
      expect(result.value, "Hello, I'm Henry I am 29.0 years old and I live in Vienna");
    });

    test('bind non-existent property throws error', () {
      final user = User('Ivan', 31, Address('Prague', 'Czech Republic'));

      final result = KodiScript.builder('user.nonExistent').bind('user', user).execute();

      expect(result.hasErrors, true);
      expect(result.errors.first, contains('nonExistent'));
    });

    test('bind with variables', () {
      final calc = Calculator();

      const source = '''
        let x = 10
        let y = 5
        calc.add(x, y)
      ''';

      final result = KodiScript.builder(source).bind('calc', calc).execute();

      expect(result.hasErrors, false);
      expect(result.value, 15.0);
    });

    test('bind in loop', () {
      final calc = Calculator();

      const source = '''
        let numbers = [1, 2, 3, 4, 5]
        let sum = 0
        for (n in numbers) {
          sum = calc.add(sum, n)
        }
        sum
      ''';

      final result = KodiScript.builder(source).bind('calc', calc).execute();

      expect(result.hasErrors, false);
      expect(result.value, 15.0);
    });

    test('bind method with multiple arguments', () {
      final calc = Calculator();

      final result = KodiScript.builder('calc.multiply(6, 7)').bind('calc', calc).execute();

      if (result.hasErrors) {
        print('Errors: ${result.errors}');
      }
      expect(result.hasErrors, false, reason: result.errors.join(', '));
      expect(result.value, 42.0);
    });
  });
}
