import 'package:test/test.dart';
import 'package:kodi_script/kodi_script.dart';

void main() {
  group('KodiScript', () {
    group('Basic Expressions', () {
      test('evaluates number literals', () {
        expect(KodiScript.eval('42'), equals(42.0));
        expect(KodiScript.eval('3.14'), equals(3.14));
      });

      test('evaluates string literals', () {
        expect(KodiScript.eval('"hello"'), equals('hello'));
      });

      test('evaluates boolean literals', () {
        expect(KodiScript.eval('true'), equals(true));
        expect(KodiScript.eval('false'), equals(false));
      });

      test('evaluates null literal', () {
        expect(KodiScript.eval('null'), isNull);
      });

      test('evaluates arithmetic', () {
        expect(KodiScript.eval('2 + 3'), equals(5.0));
        expect(KodiScript.eval('10 - 4'), equals(6.0));
        expect(KodiScript.eval('3 * 4'), equals(12.0));
        expect(KodiScript.eval('15 / 3'), equals(5.0));
      });

      test('evaluates comparison', () {
        expect(KodiScript.eval('5 > 3'), equals(true));
        expect(KodiScript.eval('3 < 5'), equals(true));
        expect(KodiScript.eval('5 == 5'), equals(true));
        expect(KodiScript.eval('5 != 3'), equals(true));
      });

      test('evaluates logical operators', () {
        expect(KodiScript.eval('true && true'), equals(true));
        expect(KodiScript.eval('true && false'), equals(false));
        expect(KodiScript.eval('false || true'), equals(true));
        expect(KodiScript.eval('!true'), equals(false));
      });
    });

    group('Variables', () {
      test('declares and uses variables', () {
        expect(KodiScript.eval('let x = 10\nx'), equals(10.0));
      });

      test('reassigns variables', () {
        expect(KodiScript.eval('let x = 5\nx = 10\nx'), equals(10.0));
      });

      test('injects host variables', () {
        final result = KodiScript.run(
          'name + " World"',
          variables: {'name': 'Hello'},
        );
        expect(result.value, equals('Hello World'));
      });
    });

    group('Control Flow', () {
      test('evaluates if-else', () {
        expect(
          KodiScript.eval('''
            let x = 10
            if (x > 5) {
              "big"
            } else {
              "small"
            }
          '''),
          equals('big'),
        );
      });

      test('evaluates for-in loop', () {
        final result = KodiScript.run('''
          let sum = 0
          for (n in [1, 2, 3, 4, 5]) {
            sum = sum + n
          }
          sum
        ''');
        expect(result.value, equals(15.0));
      });
    });

    group('Functions', () {
      test('defines and calls functions', () {
        expect(
          KodiScript.eval('''
            let add = fn(a, b) {
              return a + b
            }
            add(3, 4)
          '''),
          equals(7.0),
        );
      });

      test('supports closures', () {
        expect(
          KodiScript.eval('''
            let makeAdder = fn(x) {
              return fn(y) {
                return x + y
              }
            }
            let add5 = makeAdder(5)
            add5(3)
          '''),
          equals(8.0),
        );
      });
    });

    group('Arrays', () {
      test('creates arrays', () {
        final result = KodiScript.eval('[1, 2, 3]') as List;
        expect(result, equals([1.0, 2.0, 3.0]));
      });

      test('accesses array elements', () {
        expect(KodiScript.eval('[10, 20, 30][1]'), equals(20.0));
      });
    });

    group('Objects', () {
      test('creates objects', () {
        final result = KodiScript.eval('{name: "Alice", age: 30}') as Map;
        expect(result['name'], equals('Alice'));
        expect(result['age'], equals(30.0));
      });

      test('accesses object properties', () {
        expect(
          KodiScript.eval('let obj = {x: 10}\nobj.x'),
          equals(10.0),
        );
      });

      test('safe access returns null', () {
        expect(
          KodiScript.eval('let obj = null\nobj?.x'),
          isNull,
        );
      });

      test('elvis operator provides default', () {
        expect(
          KodiScript.eval('null ?: "default"'),
          equals('default'),
        );
      });
    });

    group('Native Functions', () {
      test('string functions', () {
        expect(KodiScript.eval('toUpperCase("hello")'), equals('HELLO'));
        expect(KodiScript.eval('toLowerCase("HELLO")'), equals('hello'));
        expect(KodiScript.eval('length("hello")'), equals(5.0));
        expect(KodiScript.eval('trim("  hi  ")'), equals('hi'));
      });

      test('math functions', () {
        expect(KodiScript.eval('abs(-5)'), equals(5.0));
        expect(KodiScript.eval('floor(3.7)'), equals(3.0));
        expect(KodiScript.eval('ceil(3.2)'), equals(4.0));
        expect(KodiScript.eval('pow(2, 3)'), equals(8.0));
      });

      test('type functions', () {
        expect(KodiScript.eval('typeOf(42)'), equals('number'));
        expect(KodiScript.eval('typeOf("hi")'), equals('string'));
        expect(KodiScript.eval('isNull(null)'), equals(true));
        expect(KodiScript.eval('isNumber(42)'), equals(true));
      });

      test('array functions', () {
        expect(KodiScript.eval('size([1,2,3])'), equals(3.0));
        expect(KodiScript.eval('first([1,2,3])'), equals(1.0));
        expect(KodiScript.eval('last([1,2,3])'), equals(3.0));
      });
    });

    group('Print Output', () {
      test('captures print output', () {
        final result = KodiScript.run('''
          print("Hello")
          print("World")
        ''');
        expect(result.output, equals(['Hello', 'World']));
      });
    });

    group('Custom Functions', () {
      test('registers and calls custom function', () {
        final result = KodiScript.builder('double(21)')
            .registerFunction('double', (args) => (args[0] as double) * 2)
            .execute();
        expect(result.value, equals(42.0));
      });
    });
  });
}
