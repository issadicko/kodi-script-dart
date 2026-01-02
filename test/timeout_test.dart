import 'package:kodi_script/kodi_script.dart';
import 'package:test/test.dart';

void main() {
  group('Timeout Tests', () {
    test('simple script completes within timeout', () {
      final result = KodiScript.builder('''
        let x = 1
        let y = 2
        x + y
      ''').withTimeout(Duration(seconds: 5)).execute();

      expect(result.hasErrors, isFalse);
    });

    test('long loop exceeds timeout', () {
      final largeArray = List<double>.generate(1000000, (i) => i.toDouble());

      final stopwatch = Stopwatch()..start();
      final result = KodiScript.builder('''
        let sum = 0
        for (i in arr) {
          sum = sum + i
        }
        sum
      ''')
          .withVariable('arr', largeArray)
          .withTimeout(Duration(milliseconds: 50))
          .execute();
      stopwatch.stop();

      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('execution timeout'));
      expect(stopwatch.elapsedMilliseconds, lessThan(200),
          reason: "Should stop execution quickly");
    });

    test('nested loops respect timeout', () {
      final result = KodiScript.builder('''
        let count = 0
        for (i in [1, 2, 3]) {
          for (j in [1, 2, 3]) {
            count = count + 1
            // Simulated work
            for (k in [1, 2, 3, 4, 5]) {
               count = count + 1
            }
          }
        }
        count
      ''').withTimeout(Duration(seconds: 5)).execute();

      expect(result.hasErrors, isFalse);
    });

    test('no timeout by default', () {
      final result = KodiScript.builder('''
        let sum = 0
        for (i in [1, 2, 3, 4, 5]) {
          sum = sum + i
        }
        sum
      ''').execute();

      expect(result.hasErrors, isFalse);
    });
  });
}
