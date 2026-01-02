import 'package:kodi_script/kodi_script.dart';
import 'package:test/test.dart';

void main() {
  group('Operation Limit', () {
    test('simple script completes within limit', () {
      final result = KodiScript.builder('''
        let x = 1
        let y = 2
        x + y
      ''').withMaxOperations(100).execute();

      expect(result.value, equals(3.0));
      expect(result.hasErrors, isFalse);
    });

    test('exceeds operation limit', () {
      final result = KodiScript.builder('''
        let sum = 0
        for (i in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
          sum = sum + i
        }
        sum
      ''').withMaxOperations(5).execute();

      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('max operations exceeded'));
    });

    test('infinite loop protection', () {
      final largeArray = List<double>.generate(10000, (i) => i.toDouble());

      final result = KodiScript.builder('''
        let sum = 0
        for (i in arr) {
          sum = sum + i
        }
        sum
      ''').withVariable('arr', largeArray)
        .withMaxOperations(100)
        .execute();

      expect(result.hasErrors, isTrue);
    });

    test('nested loops respect limit', () {
      final result = KodiScript.builder('''
        let count = 0
        for (i in [1, 2, 3, 4, 5]) {
          for (j in [1, 2, 3, 4, 5]) {
            count = count + 1
          }
        }
        count
      ''').withMaxOperations(10).execute();

      expect(result.hasErrors, isTrue);
    });

    test('no limit by default', () {
      final result = KodiScript.builder('''
        let sum = 0
        for (i in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
          sum = sum + i
        }
        sum
      ''').execute();

      expect(result.value, equals(55.0));
      expect(result.hasErrors, isFalse);
    });

    test('zero means unlimited', () {
      final result = KodiScript.builder('''
        let sum = 0
        for (i in [1, 2, 3, 4, 5]) {
          sum = sum + i
        }
        sum
      ''').withMaxOperations(0).execute();

      expect(result.value, equals(15.0));
      expect(result.hasErrors, isFalse);
    });
  });
}
