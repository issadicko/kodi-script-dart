import 'package:test/test.dart';
import 'package:kodi_script/src/reactive/rx_list.dart';
import 'package:kodi_script/src/reactive/rx_notifier.dart';

void main() {
  group('RxList', () {
    test('initialization with values', () {
      final list = RxList<int>([1, 2, 3]);
      expect(list.value, [1, 2, 3]);
      expect(list.getProperty('length'), 3);
    });

    test('initialization empty', () {
      final list = RxList<int>();
      expect(list.value, isEmpty);
      expect(list.getProperty('isEmpty'), true);
    });

    test('add notifies listeners', () {
      final list = RxList<int>();
      var notified = false;
      list.addListener(() => notified = true);

      list.callMethod('add', [1]);
      expect(list.value, [1]);
      expect(notified, true);
    });

    test('remove notifies listeners', () {
      final list = RxList<int>([1, 2]);
      var notified = false;
      list.addListener(() => notified = true);

      list.callMethod('remove', [1]);
      expect(list.value, [2]);
      expect(notified, true);
    });

    test('access properties captures dependency', () {
      final list = RxList<int>([1]);
      final notifier = RxNotifier.instance;
      
      notifier.startCapture();
      list.getProperty('length');
      final deps = notifier.stopCapture();
      
      expect(deps, contains(list));
    });

    test('map returns new list', () {
      final list = RxList<int>([1, 2, 3]);
      final result = list.callMethod('map', [(x) => x * 2]);
      expect(result, [2, 4, 6]);
    });

    test('filter (where) returns filtered list', () {
      final list = RxList<int>([1, 2, 3, 4]);
      final result = list.callMethod('filter', [(x) => x % 2 == 0]);
      expect(result, [2, 4]);
    });

    test('contains check', () {
      final list = RxList<int>([1, 2, 3]);
      expect(list.callMethod('contains', [2]), true);
      expect(list.callMethod('contains', [99]), false);
    });
  });
}
